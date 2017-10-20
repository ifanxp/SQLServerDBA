--tempdb数据库的空间使用  
/*======================================================  
tempdb中包含的对象：  
  
用户对象：是用户显式创建的，这些对象位于用户会话的作用域，  
         可以位于创建对象的例程(存储过程、触发器、函数)的作用域中。  
    1.用户定义的表、索引  
    2.系统表、索引  
    3.全局临时表、索引  
    4.局部临时表、索引  
    5.表变量  
    6.表值函数中返回的表  
  
内部对象：是根据需要由SQL Server数据库引擎创建的，用于处理SQL Server语句，  
          内部对象可以在语句作用域中创建、删除。  
          每个内部对象至少需要9个页面，一个IAM页，一个区包含了8个页。  
    1.游标、假脱机操作、临时的大型对象(LOB)，存储的工作表  
    2.哈希联接、哈希聚合操作的工作文件  
    3.如果设置了sort_in_tempdb选项，那么创建、重新生成索引的重建排序结果存放在tempdb；  
      group by、order by、union操作的中间结果。  
  
版本存储区：是数据页的集合，包含了支持行版本控制功能的所需的数据，主要支持快照事务隔离级别，  
            以及一些其他的提高数据库并发性能的新功能。  
    1.公用版本存储区：在使用快照隔离级别、已提交读隔离级别的数据库中，由数据修改事务生成的行版本。  
    2.联机索引生成版本存储区：为了实现联机索引操作而为数据修改事务生成的行版本，  
      多个活动结果集，after触发器生成的行版本。   
    
                     
上面也提到了，由于sys.allocation_units和sys.partitions视图没有记录tempdb中的内部对象、版本存储区  
所以这2个视图和sp_spaceused，不能准确反应出tempdb的空间使用。  
  
  
分析tempdb现有的工作负载:  
    1.设置tempdb的自动增长  
    2.通过模拟单独的查询、工作任务，监控tempdb空间使用  
    3.通过模拟执行一些系统维护操作(重新生成索引),监控tempdb空间使用  
    4.根据2和3中tempdb的空间使用量,预测总工作负荷会使用的空间,并针对任务的并发度调整这个值.  
    5.根据4得到的值,设置生成环境中tempdb的初始大小,并开启自动增长.  
      另外,tempdb的文件个数和大小,不仅需要满足实际使用需要,还要考虑性能优化.  
  
  
监控tempdb的空间使用方法:  
    1.可以通过SQL Trace来跟踪,但是由于不能预期造成大量使用tempdb语句在什么时候运行,  
      而且SQL Trance操作比较昂贵,如果一直开着会产生大量的跟踪文件,对硬盘的负担也比较重,一般不用.  
        
    2.轻量级的监控是通过一定时间间隔运行能够监控系统运行的dbcc命令、动态性能视图-函数，  
      把结果记录在文件中，这对于很繁忙的系统是不错的选择。  
          
========================================================*/    
  
Select DB_NAME(database_id) as DB,   
       max(FILE_ID) as '文件id',           
            
       SUM (user_object_reserved_page_count) as '用户对象保留的页数',       ----包含已分配区中的未使用页数  
       SUM (internal_object_reserved_page_count) as '内部对象保留的页数',   --包含已分配区中的未使用页数  
       SUM (version_store_reserved_page_count)  as '版本存储保留的页数',       
       SUM (unallocated_extent_page_count) as '未分配的区中包含的页数',     --不包含已分配区中的未使用页数     
         
       SUM(mixed_extent_page_count) as '文件的已分配混合区中:已分配页和未分配页'  --包含IAM页                           
From sys.dm_db_file_space_usage                                            
Where database_id = 2    
group by DB_NAME(database_id)     
                   
                                                   
--能够反映当时tempdb空间的总体分配,申请空间的会话正在运行的语句  
SELECT   
       t1.session_id,          
                                                     
       t1.internal_objects_alloc_page_count,        
       t1.user_objects_alloc_page_count,  
         
       t1.internal_objects_dealloc_page_count ,   
       t1.user_objects_dealloc_page_count,  
       t.text  
from sys.dm_db_session_space_usage  t1   --反映每个session的累计空间申请                                  
inner join sys.dm_exec_sessions as t2   
        on t1.session_id = t2.session_id             
inner join sys.dm_exec_requests t3  
        on t2.session_id = t3.session_id                  
cross apply sys.dm_exec_sql_text(t3.sql_handle) t  
where  t1.internal_objects_alloc_page_count>0   or  
       t1.user_objects_alloc_page_count >0      or  
       t1.internal_objects_dealloc_page_count>0 or  
       t1.user_objects_dealloc_page_count>0      
             
      
      
--返回tempdb中页分配和释放活动，  
--只有当任务正在运行时，sys.dm_db_task_space_usage才会返回值  
--在请求完成时，这些值将按session聚合体现在SYS.dm_db_session_space_usage  
select t.session_id,  
       t.request_id,  
       t.database_id,  
         
       t.user_objects_alloc_page_count,  
       t.internal_objects_dealloc_page_count,  
         
       t.internal_objects_alloc_page_count,  
       t.internal_objects_dealloc_page_count  
from sys.dm_db_task_space_usage t     
inner join sys.dm_exec_sessions e  
        on t.session_id = e.session_id          
inner join sys.dm_exec_requests  r      
        on t.session_id = r.session_id and  
           t.request_id = r.request_id  
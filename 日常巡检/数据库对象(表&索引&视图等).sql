--不一定准确:某个表的行数,保留大小，数据大小，索引大小，未使用大小  
exec sp_spaceused @objname ='temp_lock'  
  
  
--准确:但有性能影响  
exec sp_spaceused @objname ='temp_lock',  
                  @updateusage ='true'  
  
  
  
--按页统计，没有性能影响，有时不准确  
/*======================================================  
一次计算多个对象的空间使用情况  
  
sys.dm_db_partition_stats返回当前数据库中每个分区(表和索引)的页和行计数信息  
========================================================*/     
select o.name,  
       sum(p.reserved_page_count) as reserved_page_count, --保留页，包含表和索引  
         
       sum(p.used_page_count) as used_page_count,         --已使用页，包含表和索引  
         
       sum(case when p.index_id <2   
                     then p.in_row_data_page_count +   
                          p.lob_used_page_count +   
                          p.row_overflow_used_page_count  
                else p.lob_used_page_count +   
                     p.row_overflow_used_page_count  
           end) as data_pages,  --数据页,包含表中数据、索引中的lob数据、索引中的行溢出数据  
         
       sum(case when p.index_id < 2   
                     then p.row_count  
                else 0  
           end) as row_counts   --数据行数，包含表中的数据行数，不包含索引中的数据条目数  
             
from sys.dm_db_partition_stats p  
inner join sys.objects o  
        on p.object_id = o.object_id   
where p.object_id= object_id('表名')  
group by o.name     
  
   
  
--按页或区统计，有性能影响，准确           
--显示当前数据库中所有的表或视图的数据和索引的空间信息  
--包含：逻辑碎片、区碎片(碎片率)、平均页密度                 
dbcc showcontig(temp_lock)  
  
  
  
--SQL Server推荐使用的动态性能函数，准确  
select *  
from sys.dm_db_index_physical_stats(  
        db_id('test'),                      --数据库id  
        object_id('test.dbo.temp_lock'),    --对象id  
        null,                               --索引id  
        null,                               --分区号  
          
        'limited'   --default,null,'limited','sampled','detailed',默认为'limited'  
                    --'limited'模式运行最快，扫描的页数最少,对于堆会扫描所有页,对于索引只扫描叶级以上的父级页  
                    --'sampled'模式会返回堆、索引中所有页的1%样本的统计信息，如果少于1000页，那么用'detailed'代替'sampled'  
                    --'detailed'模式会扫描所有页,返回所有统计信息  
    )  
  
  
  
--查找哪些对象是需要重建的  
use test  
go  
  
if OBJECT_ID('extentinfo') is not null  
    drop table extentinfo  
go  
  
create table extentinfo   
(   [file_id] smallint,   
    page_id int,   
    pg_alloc int,                 
    ext_size int,                  
    obj_id int,                    
  
    index_id int,                  
    partition_number int,  
    partition_id bigint,  
    iam_chain_type varchar(50),    
    pfs_bytes varbinary(10)   
)   
go   
  
  
/*====================================================================  
查询到的盘区信息是数据库的数据文件的盘区信息，日志文件不以盘区为单位  
  
命令格式:  DBCC EXTENTINFO（dbname,tablename,indexid）  
  
DBCC EXTENTINFO('[test]','extentinfo',0)  
======================================================================*/  
insert extentinfo   
exec('dbcc extentinfo(''test'') ')  
go  
  
  
--每一个区有一条数据  
select  file_id,   
        obj_id,               --对象ID  
        index_id,             --索引id  
                  
        page_id,              --这个区是从哪个页开始的,也就是这个区中的第一个页面的页面号  
        pg_alloc,             --这个盘区分配的页面数量  
          
        ext_size,             --这个盘区包含了多少页  
  
        partition_number,  
        partition_id,  
        iam_chain_type,       --IAM链类型:行内数据,行溢出数据,大对象数据  
        pfs_bytes   
from extentinfo  
order by file_id,  
         OBJ_ID,  
         index_id,  
         partition_id,  
         ext_size  
   
  
/*=====================================================================================================  
数据库的数据文件的盘区信息,通过计算每个对象理论上区的数量和实际数量,如果两者相差很大,  
那就应该重建对象.  
  
1.每一条记录就是一个区  
  
2.如果pg_alloc比ext_size小，也就是实际每个区分配的页数小于理论上这个区的页数，  
  那么就会多一条记录，把本应该属于这个区的页放到多出来的这条记录对应的区中，  
  那么原来只有一条记录(也就是一个区)，现在就有2条记录(也就是2个区)，  
  导致实际的区数量2大于理论上的区数量1.  
========================================================================================================*/  
select file_id,  
       obj_id,   
       index_id,   
       partition_id,   
       ext_size,   
         
       count(*) as '实际区的个数',   
       sum(pg_alloc) as '实际包含的页数',   
         
       ceiling(sum(pg_alloc) * 1.0 / ext_size) as '理论上的区的个数',   
       ceiling(sum(pg_alloc) * 1.0 / ext_size) / count(*) * 100.00 as '理论上的区个数 / 实际区的个数'   
         
from extentinfo   
group by file_id,  
         obj_id,   
         index_id,  
         partition_id,   
         ext_size   
having ceiling(sum(pg_alloc)*1.0/ext_size) < count(*)     
--过滤: 理论上区的个数 < 实际区的个数,也就是百分比小于100%的  
order by partition_id, obj_id, index_id, [file_id]
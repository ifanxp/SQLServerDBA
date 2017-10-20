/*** 检查数据库完整性 ***/
dbcc checkdb(test)  
dbcc checkdb(test) with tablock  --通过加tablock提高速度

/*** 数据库重命名、修改恢复模式、修改用户模式 ***/
--数据库重命名    
ALTER DATABASE WC    
MODIFY NAME = test   
  

--设置数据库为完整恢复模式  
alter database test  
set recovery full  
  
  
--只允许一个用户访问数据库    
alter database test    
set single_user     
with rollback after 10 seconds --指定多少秒后回滚事务    
    
    
--只有sysadmin,dbcreator,db_owner角色的成员可以访问数据库    
alter database wc    
set restricted_user     
with rollback immediate        --立即回滚事务    
    
    
--多用户模式   
alter database wc    
set multi_user    
with no_wait       --不等待立即改变，如不能立即完成，那么会导致执行错误    


/*** 扩展数据库：增加文件组、增加文件、修改文件大小、修改文件的逻辑名称 ***/
--添加文件组  
ALTER DATABASE test  
ADD FILEGROUP WC_FG8  
  
  
--添加数据文件  
ALTER DATABASE test  
ADD FILE  
(  
    NAME = WC_FG8,  
    FILENAME = 'D:\WC_FG8.ndf',  
    SIZE = 1mb,  
    MAXSIZE = 10mb,  
    FILEGROWTH = 1mb  
)  
TO FILEGROUP WC_FG8  
  
  
--添加日志文件  
ALTER DATABASE test  
ADD LOG FILE  
(  
    NAME = WC_LOG3,  
    FILENAME = 'D:\WC_FG3.LDF',  
    SIZE = 1MB,  
    MAXSIZE = 10MB,  
    FILEGROWTH = 100KB  
)  
  
  
--修改数据文件的大小,增长大小,最大大小  
ALTER DATABASE test  
MODIFY FILE  
(  
    NAME = 'WC_FG8',  
    SIZE = 2MB,      --必须大于之前的大小,否则报错  
    MAXSIZE= 8MB,  
    FILEGROWTH = 10%  
)  
  
  
--修改数据文件或日志文件的逻辑名称  
ALTER DATABASE test  
MODIFY FILE  
(  
    NAME = WC_LOG3,  
    NEWNAME = WC_FG33  
)  


/*** 移动文件 ***/
--由于在SQL Server中文件组、文件不能离线  
--所以必须把整个数据库设置为离线  
checkpoint  
go  
  
ALTER DATABASE WC  
SET OFFLINE  
go  
  
  
--修改文件名称  
ALTER DATABASE WC  
MODIFY FILE  
(  
    NAME = WC_fg8,  
    FILENAME = 'D:\WC\WC_FG8.NDF'  
)  
go  
  
  
--把原来的文件复制到新的位置：'D:\WC\WC_FG8.NDF'  
  
  
--设置数据库在线  
ALTER DATABASE WC  
SET ONLINE  



/*** 设置默认文件组、只读文件组 ***/
--设置默认文件组  
ALTER DATABASE WC  
MODIFY FILEGROUP WC_FG8 DEFAULT  
  
  
--设为只读文件组  
--如果文件已经是某个属性，不能再次设置相同属性  
ALTER DATABASE WC  
MODIFY FILEGROUP WC_FG8 READ_WRITE  



/*** 收缩数据库、收缩文件 ***/
--收缩数据库    
DBCC SHRINKDATABASE('test',    --要收缩的数据库名称或数据库ID    
                    10         --收缩后，数据库文件中空间空间占用的百分比    
                    )    
    
    
DBCC SHRINKDATABASE('test',    --要收缩的数据库名称或数据库ID    
                    10,        --收缩后，数据库文件中空闲空间占用的百分比    
                    NOTRUNCATE --在收缩时，通过数据移动来腾出自由空间    
                    )    
                 
                        
DBCC SHRINKDATABASE('test',      --要收缩的数据库名称或数据库ID    
                    10,          --收缩后，数据库文件中空间空间占用的百分比    
                    TRUNCATEONLY --在收缩时，只是把文件尾部的空闲空间释放    
                    )    
                        
    
--收缩文件    
DBCC SHRINKFILE(wc_fg8,   --要收缩的数据文件逻辑名称    
                7         --要收缩的目标大小，以MB为单位    
                )    
                    
DBCC SHRINKFILE(wc_fg8,   --要收缩的数据文件逻辑名称    
                EMPTYFILE --清空文件，清空文件后，才可以删除文件    
                )   



/*** 删除文件、删除文件组 ***/
--要删除文件，必须要先把文件上的数据删除，或者移动到其他文件或文件组上  
--可以清空文件的内容  
DBCC SHRINKFILE(WC_FG8,EMPTYFILE)  
  
  
--删除文件，同时也在文件系统底层删除了文件  
ALTER DATABASE test  
REMOVE FILE WC_FG8  
  
  
--要删除文件组，必须先删除所有文件  
  
  
--最后删除文件组  
ALTER DATABASE test  
REMOVE FILEGROUP WC_FG8  
  
/*  
drop database www  
go  
  
create database www  
on primary  
(  
name = 'www_data01',  
filename = 'c:\www_data01.mdf'  
),  
(  
name = 'www_data02',  
filename ='c:\www_data02.ndf'  
)  
  
log on  
(  
name = 'www_log',  
filename = 'c:\www_log.ldf'  
)  
go  
  
use www  
go  
  
create table a(id int ,v varchar(10)) on [primary]  
go  
  
insert into a  
select OBJECT_ID,left(name,10) from sys.objects   
go  
  
  
insert into a  
select * from a  
go 10  
  
  
DBCC SHRINKFILE(www_data02,EMPTYFILE)   
go  
  
ALTER DATABASE www    
REMOVE FILE www_data02   
*/  



/*** 重新组织索引 ***/
ALTER INDEX [idx_temp_lock_id] ON [dbo].[temp_lock]   
REORGANIZE   
WITH ( LOB_COMPACTION = ON )  

--批量生成重组索引的语句
use test  
go  
  
select 'DBCC INDEXDEFRAG('+db_name()+','+o.name+','+i.name + ');'  
        --,db_name(),  
        --o.name,  
        --i.name,  
        --i.*  
  
from sysindexes i  
inner join sysobjects o  
        on i.id = o.id  
where o.xtype = 'U'  
      and i.indid >0  
      and charindex('WA_Sys',i.name) = 0  



/*** 重新生成索引 ***/
ALTER INDEX [idx_temp_lock_id] ON [dbo].[temp_lock]   
REBUILD PARTITION = ALL   
WITH ( PAD_INDEX  = OFF,   
       STATISTICS_NORECOMPUTE  = OFF,   
       ALLOW_ROW_LOCKS  = ON,   
       ALLOW_PAGE_LOCKS  = ON,   
       ONLINE = OFF,   
       SORT_IN_TEMPDB = OFF )  


/*** 更新统计信息 ***/
--更新表中某个的统计信息    
update statistics temp_lock(_WA_Sys_00000001_07020F21)    
    
    
update statistics temp_lock(_WA_Sys_00000001_07020F21)    
with sample 50 percent    
    
    
update statistics temp_lock(_WA_Sys_00000001_07020F21)    
with resample,    --使用最近的采样速率更新每个统计信息    
     norecompute  --查询优化器将完成此统计信息更新并禁用将来的更新    
    
    
    
--更新索引的统计信息    
update statistics temp_lock(idx_temp_lock_id)    
with fullscan            
    
    
--更新表的所有统计信息    
update statistics txt    
with all     



/*** 执行SQL Server代理作业 ***/
exec msdb.dbo.sp_start_job   
    @job_name =N'job_update_sql';  



/*** 备份数据库(完整、差异、日志备份) ***/

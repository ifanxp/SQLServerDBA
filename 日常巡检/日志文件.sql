--查看日志文件所在数据库、路径、状态、大小  
select db_name(database_id) dbname,  
       type_desc,      --数据还是日志  
       name,           --文件的逻辑名称  
       physical_name,  --文件的物理路径  
       state_desc,     --文件状态  
       size * 8.0/1024 as '文件大小（MB）'          
from sys.master_files  
where type_desc = 'LOG'  
  
  
  
--所有数据库的日志的大小,空间使用率  
dbcc sqlperf(logspace)  
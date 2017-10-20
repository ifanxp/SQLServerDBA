--查看某个数据库中的所有文件及大小  
sp_helpfile   
  
  
  
--查看所有文件所在数据库、路径、状态、大小  
select db_name(database_id) dbname,  
       type_desc,      --数据还是日志  
       name,           --文件的逻辑名称  
       physical_name,  --文件的物理路径  
       state_desc,     --文件状态  
       size * 8.0/1024 as '文件大小（MB）'          
from sys.master_files  
  
  
  
--按区extent计算空间，没有性能影响，基本准确,把TotalExtents*64/1024,单位为MB  
--同时也适用于计算tempdb的文件大小，但不包括日志文件  
dbcc showfilestats  
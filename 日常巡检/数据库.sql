--所有数据库的大小  
exec sp_helpdb  
  
  
--所有数据库的状态  
select name,  
       user_access_desc,           --用户访问模式  
       state_desc,                 --数据库状态  
       recovery_model_desc,        --恢复模式  
       page_verify_option_desc,    --页检测选项  
       log_reuse_wait_desc         --日志重用等待  
from sys.databases  
  
  
--某个数据库的大小:按页面计算空间，有性能影响，基本准确，有时不准确  
use test  
go  
  
exec sp_spaceused    
go  
  
  
  
--可以@updateusage = 'true',会运行dbcc updateusage  
exec sp_spaceused  @updateusage = 'true'  
  
  
--对某个数据库,显示目录视图中的页数和行数错误并更正  
DBCC UPDATEUSAGE('test')  

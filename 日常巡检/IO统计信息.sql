--数据和日志文件的I/O统计信息,包含文件大小  
    select database_id,  
           file_id,  
           file_handle,           --windows文件句柄  
           sample_ms,             --自从计算机启动以来的毫秒数  
             
           num_of_reads,  
           num_of_bytes_read,  
           io_stall_read_ms,      --等待读取的时间  
             
           num_of_writes,  
           num_of_bytes_written,  
           io_stall_write_ms,  
             
           io_stall,              --用户等待文件完成I/O操作所用的总时间  
           size_on_disk_bytes     --文件在磁盘上所占用的实际字节数          
             
    from sys.dm_io_virtual_file_stats(db_id('test'),   --数据库id  
                                       1 )  --数据文件id                                         
    union all  
      
    select database_id,  
           file_id,  
           file_handle,           --windows文件句柄  
           sample_ms,             --自从计算机启动以来的毫秒数  
             
           num_of_reads,  
           num_of_bytes_read,  
           io_stall_read_ms,      --等待读取的时间  
             
           num_of_writes,  
           num_of_bytes_written,  
           io_stall_write_ms,  
             
           io_stall,              --用户等待文件完成I/O操作所用的总时间  
           size_on_disk_bytes     --文件在磁盘上所占用的实际字节数   
    from sys.dm_io_virtual_file_stats( db_id('test'),   --数据库id  
                                       2 )  --日志文件id 
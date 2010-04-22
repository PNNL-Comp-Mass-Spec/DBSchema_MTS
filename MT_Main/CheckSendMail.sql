/****** Object:  StoredProcedure [dbo].[CheckSendMail] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Procedure CheckSendMail
As
	/* set nocount on */
	
    declare @myError int
    declare @type varchar(32)
    declare @cnt int
    declare @message varchar(500)
    declare @rowcnt int
    declare @subject varchar(80)
    declare @to varchar(128)
    
    set @rowcnt = 0
    set @subject = 'Notification from PRISM MTS Server'
    set @message = '<H1>' + @subject + '</H1><HR><UL>'
    
    set @to = 'grkiebel@pnl.gov' -- '' Kenneth.Auberry@pnl.gov  Dave.Clark@pnl.gov
    
----    exec KickWatchdog 'CheckForLogErrors'

/*
    DECLARE default_cursor CURSOR LOCAL FORWARD_ONLY  FOR 
	SELECT type, COUNT(type) AS cnt 
		FROM T_Log_Entries 
		WHERE (DATEDIFF(day, posting_time, GETDATE()) <= 1) 
		GROUP BY type  
	set @myError = @@error
     
    OPEN default_cursor
    set @myError = @@error
     
    FETCH NEXT FROM default_cursor 
    INTO @type, @cnt
    set @myError = @@error
      
     
    WHILE @@FETCH_STATUS = 0 and @myError = 0
    BEGIN
      set @rowcnt = @rowcnt + 1
      set @message = @message + '<LI>There have been ' + convert(varchar(12), @cnt) + ' ' + @type + ' messages logged.</LI>'
      FETCH NEXT FROM default_cursor 
      INTO @type, @cnt
      set @myError = @@error
    END
     
    CLOSE default_cursor
     
    DEALLOCATE default_cursor
 */  
----    if @rowcnt > 0
 ----   begin
		set @message = @message + '</UL>'
		set @message = @message + 'This is an automatic notification from the PRISM Mass Tag System (MTS) server</BR></BR>'
		set @message = @message + 'Hot Damn!!  We can send email from SQLServer on pogo!!!  In HTML format even!!!</BR>'
		set @message = @message + '<BR><A HREF="http://pogo/mts/mtmain_log_list_report.asp">Examine Log</A>'
		exec SendMail 'pnl.gov', @to, @subject, @message
----    end
	return



GO
GRANT EXECUTE ON [dbo].[CheckSendMail] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[CheckSendMail] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[CheckSendMail] TO [MTS_DB_Lite] AS [dbo]
GO

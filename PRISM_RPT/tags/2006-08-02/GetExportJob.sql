SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[GetExportJob]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[GetExportJob]
GO

CREATE PROCEDURE GetExportJob
/****************************************************	
**  Desc: This procedure selects a candidate export job from the
**		  T_QR_Export_Job table.  It returns the oldest job with
**		  status of 1 (new).  The record is locked to prevent
**		  a race condition and the status is updated to working.
**
**  Return values: 0 if success, otherwise, error code 
**
**  Parameters: 
**		The jobkey is the unique record key that allows status updates.
**		The dbname is the name of the MassTag database.
**		The qid_list is a comma seperated list of QRollup IDs.
**
**  Auth: jee
**	Date: 07/01/2004
**		  12/09/2004 mem - Added ServerName parameter that specifies the server that the given DB is present on
**		  04/05/2005 mem - Added parameter @verbose_output_columns
**
****************************************************/
(
	@jobkey int OUTPUT ,
	@dbname varchar(128) = '' OUTPUT,
	@qid_list varchar(100) = '' OUTPUT,
	@email_address varchar(100) = '' OUTPUT, 
	@prot_column varchar(50) = '' OUTPUT, 
	@pep_column varchar(50) = '' OUTPUT, 
	@rep_cnt_avg_min float = 0 OUTPUT, 
	@propep_select smallint = 0 OUTPUT, 
	@crosstab_select smallint = 0 OUTPUT, 
	@send_mail smallint = 0 OUTPUT, 
	@gen_pep bit = 0 OUTPUT, 
	@include_prot bit = 0 OUTPUT, 
	@gen_prot bit = 0 OUTPUT, 
	@prot_avg bit = 0 OUTPUT, 
	@gen_prot_crosstab bit = 0 OUTPUT, 
	@gen_pep_crosstab bit = 0 OUTPUT, 
	@pep_avg bit = 0 OUTPUT, 
	@gen_propep_crosstab bit = 0 OUTPUT,
	@servername varchar(64) = '' OUTPUT,
	@verbose_output_columns bit = 0 OUTPUT
)
AS
	
	set NoCount On
	
	declare @myError int
	declare @rows int
	declare @transName varchar(32)
	
	declare @message varchar(256)
	declare @dbType tinyint
	declare @jobAvailable tinyint
	
	set @myError = 0
	set @jobAvailable = 0
	
	set @message = ''
	set @dbType= 0
	
   	---------------------------------------------------
	-- Start transaction
	---------------------------------------------------
	--
	set @transName = 'GetExportJob'
	begin transaction @transName
	
	SELECT     TOP 1 @jobkey = jobkey, @dbname = dbname, @qid_list = qid_list, @email_address = email_address, 
					 @prot_column = prot_column, @pep_column = pep_column, @rep_cnt_avg_min = rep_cnt_avg_min, 
					 @propep_select = propep_select, @crosstab_select = crosstab_select, @send_mail = send_mail, 
					 @gen_pep = gen_pep, @include_prot = include_prot, @gen_prot = gen_prot, @prot_avg = prot_avg, 
					 @gen_prot_crosstab = gen_prot_crosstab, @gen_pep_crosstab = gen_pep_crosstab, @pep_avg = pep_avg, 
					 @gen_propep_crosstab = gen_propep_crosstab,
					 @verbose_output_columns = Verbose_Output_Columns
	FROM         T_QR_Export_Job WITH (HOLDLOCK)
	WHERE     (statuskey = 1)

	
	SELECT @myError = @@error, @rows = @@rowcount
	
	if @myError = 0 and @rows = 1
	begin
		set @jobAvailable = 1
	end
	
	if @jobAvailable = 1
	begin
		-- Update the Job status key to 2
		execute @myError = UpdateJobStatus @jobkey, 2

		-- Lookup the server that the given DB is located on
		set @dbType = 1
		execute @myError = MTS_Master.dbo.GetDBLocation @dbname, @dbType, @serverName = @serverName Output
		
		if Len(IsNull(@serverName, '')) = 0
		begin
			/* Server not found for @dbName (or @dbName is not a PMT tag DB) */
			set @myError = 52002
			Set @message = 'Server not found for DB ' + @dbName + ' when calling MTS_Master.dbo.GetDBLocation'
		end
	end
	else
	begin
		if @myError <> 0
			Set @message = 'Error retrieving next QR job from T_QR_Export_Job: Error Code ' + convert(varchar(12), @myError)
	end
		
   	---------------------------------------------------
	-- Complete transaction
	---------------------------------------------------
	--
	if @jobAvailable = 1 and @myError = 0
	begin
		commit transaction @transName
	end
	else
	begin
		rollback transaction @transName

		if @myError <> 0
		Begin
			If Len(@message) = 0
				Set @message = 'Error in GetExportJob'

			if @jobAvailable = 1
			Begin
				-- Job was available, but an error occurred, update the status key to 4
				execute @myError = UpdateJobStatus @jobkey, 4
				set @message = @message + '; StatusKey updated to State 4'
			End
			
			execute PostLogEntry 'Error', @message, 'GetExportJob'
		End
	end

	if @jobAvailable = 1 and @myError = 0
		return 0
	else
		return 52001		-- Note that this return code is used by the QR Export Manager to indicate that no jobs are available

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


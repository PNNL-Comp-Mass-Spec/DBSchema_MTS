SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[AddExportQueueEntry]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[AddExportQueueEntry]
GO

CREATE PROCEDURE AddExportQueueEntry
/****************************************************	
**  Desc: Adds and export queue entry
**
**  Return values: 0 if success, otherwise, error code 
**
**  Parameters: 
**
**  Auth: jee
**	Date: 07/01/2004
**		  10/22/2004 mem - Added PostUsageLogEntry
**		  12/10/2004 grk - Corrected column names in V_Users
**		  04/05/2005 mem - Added parameter @verbose_output_columns
**
****************************************************/
(
	@database varchar(50),
	@qid_list varchar(500),
	@email_addr varchar(100),
	@prot_column varchar(50),
	@pep_column varchar(50),
	@rep_cnt_avg_min float,
	@propep_select smallint,
	@crosstab_select smallint,
	@send_mail smallint,
	@gen_pep bit,
	@include_prot bit,
	@gen_prot bit,
	@gen_prot_crosstab bit,
	@prot_avg bit,
	@gen_pep_crosstab bit,
	@gen_propep_crosstab bit,
	@pep_avg bit,
	@job_key int OUTPUT,
	@verbose_output_columns bit = 0
)
AS
	declare @result   int
	declare @err_code int
	declare @line_cnt int
	declare @prn varchar(100)
	set @result = 0
	set @prn = @email_addr
	
	SELECT     @email_addr = U_email
	FROM         V_Users
	WHERE     (U_PRN = @prn)
	
	INSERT INTO T_QR_Export_Job
	           (modified, statuskey, dbname, qid_list, result, email_address, prot_column, pep_column, 
						  rep_cnt_avg_min, propep_select, crosstab_select, send_mail, gen_pep, include_prot, 
						  gen_prot, gen_prot_crosstab, prot_avg, gen_pep_crosstab, pep_avg, gen_propep_crosstab,
						  Verbose_Output_Columns)
	VALUES     (GetDate(), 1, @database, @qid_list, 'none', @email_addr, @prot_column, @pep_column, 
						  @rep_cnt_avg_min, @propep_select, @crosstab_select, @send_mail, @gen_pep, @include_prot, 
						  @gen_prot, @gen_prot_crosstab, @prot_avg, @gen_pep_crosstab, @pep_avg, @gen_propep_crosstab,
						  IsNull(@verbose_output_columns, 0))
						  
	SELECT     @job_key = @@IDENTITY, @err_code = @@ERROR, @line_cnt = @@ROWCOUNT
	--
	Declare @UsageMessage varchar(512)
	Set @UsageMessage = @email_addr + '; ' + Left(@qid_list, 400)
	Exec PostUsageLogEntry 'AddExportQueueEntry', @database, @UsageMessage
	
	if (@err_code <> 0) or (@line_cnt <> 1)
	begin
		set @result = @err_code
	end
	RETURN @result

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[AddExportQueueEntry]  TO [DMS_SP_User]
GO


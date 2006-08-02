SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[MasterUpdateQRProcessStart]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[MasterUpdateQRProcessStart]
GO


CREATE PROCEDURE dbo.MasterUpdateQRProcessStart
/****************************************************
** 
**		Desc:
**		Calls QuantitationProcessStart if the option is
**		enabled in T_Process_Step_Control
**
**		Return values: 0: success, otherwise, error code
** 
**		Parameters:
**
**		Auth: mem
**		Date: 10/11/2005
**    
*****************************************************/
(
	@logLevel int = 1,
	@message varchar(255)='' OUTPUT
)
As
	set nocount on
	
	declare @myError int
	set @myError = 0

	declare @myRowCount int
	set @myRowCount = 0
	
	declare @result int
	declare @countProcessed int
	set @countProcessed = 0


	set @result = 0
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'QuantitationProcessing')
	if @result > 0
	begin
		If @logLevel >= 2
			execute PostLogEntry 'Normal', 'Begin QuantitationProcessStart', 'MasterUpdateQRProcessStart'
		EXEC @result = QuantitationProcessStart @countProcessed OUTPUT

		set @message = 'Complete QuantitationProcessing: ' + convert(varchar(32), @countProcessed)
		if @result <> 0
			set @message = @message + ' (error ' + convert(varchar(32), @result) + ')'
	end
	--
	If @logLevel >= 1
	begin
		if @result = 0 and @countProcessed > 0 or @logLevel >= 2
			execute PostLogEntry 'Normal', @message, 'MasterUpdateQRProcessStart'
		else
			if @result <> 0
				execute PostLogEntry 'Error', @message, 'MasterUpdateQRProcessStart'
	end
	
 Done:
	return @myError



GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[MasterUpdateProcessImport]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[MasterUpdateProcessImport]
GO


CREATE PROCEDURE dbo.MasterUpdateProcessImport
/****************************************************
** 
**	Desc: 
**	Imports newly completed LCQ analyses for
**	 organism and imports the peptides from them
**
**	Return values: 0: success, otherwise, error code
** 
**	Parameters:
**
**	Auth:	grk
**	Date:	07/15/2004
**			07/21/2004 mem - Changed from @NextProcessState = 20 to @NextProcessState = 30 when calling LoadPeptidesForAvailableAnalyses
**			08/06/2004 mem - Added @numJobsToProcess parameter and use of @count
**			11/04/2004 mem - Removed @numJobsToProcess parameter and moved Load Peptides code to MasterUpdateProcessBackground
**			03/11/2006 mem - Now calling VerifyUpdateEnabled
**    
*****************************************************/
As
	set nocount on
	
	declare @myError int
	set @myError = 0
	
	declare @cmd varchar(255)
	declare @result int
	declare @count int
	declare @logLevel int
	declare @UpdateEnabled tinyint
	
	declare @PeptideDatabase varchar(128)
	set @PeptideDatabase = DB_Name()

	set @logLevel = 1		-- Default to normal logging

	declare @ProcessStateMatch int
	declare @NextProcessState int
	
	declare @message varchar(255)

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled @CallingFunctionDescription = 'MasterUpdateProcessImport', @AllowPausing = 0, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done

	--------------------------------------------------------------
	-- Lookup the LogLevel state
	-- 0=Off, 1=Normal, 2=Verbose, 3=Debug
	--------------------------------------------------------------
	--
	set @result = @logLevel
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'LogLevel')
	Set @logLevel = @result

	set @message = 'Begin Master Update for ' + @PeptideDatabase
	If @logLevel >= 2
		execute PostLogEntry 'Normal', @message, 'MasterUpdateProcessImport'

	--------------------------------------------------------------
	-- Refresh local copies of external tables
	--------------------------------------------------------------
	
	-- Refresh local analysis descriptions
	--
--	EXEC @result = RefreshAnalysesDescriptionStorage @message output


	--------------------------------------------------------------
	-- import new analyses from DMS
	--------------------------------------------------------------
	--
	declare @entriesAdded int
	set @entriesAdded = 0
	--
	-- < 1 >
	--
	-- Import new analyses for peptide identification, provided this step is enabled
	--
	Set @NextProcessState = 10

	set @result = 0
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'ImportNewAnalyses')
	If @result = 0
	begin
		If @logLevel >= 2
			execute PostLogEntry 'Normal', 'Skipped ImportNewAnalyses', 'MasterUpdateProcessImport'
	end
	else
	begin
		EXEC @result = ImportNewPeptideAnalyses @NextProcessState, @entriesAdded OUTPUT
	end

	--------------------------------------------------------------
	-- Normal Exit
	--------------------------------------------------------------

	set @message = 'Completed master update for ' + @PeptideDatabase + ': ' + convert(varchar(32), @myError)
	
Done:
	If (@logLevel >=1 AND @myError <> 0)
		execute PostLogEntry 'Error', @message, 'MasterUpdateProcessImport'
	Else
	If @logLevel >= 2
		execute PostLogEntry 'Normal', @message, 'MasterUpdateProcessImport'
		
	return @myError


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


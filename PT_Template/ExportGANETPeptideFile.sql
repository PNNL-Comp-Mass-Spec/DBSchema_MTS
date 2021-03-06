/****** Object:  StoredProcedure [dbo].[ExportGANETPeptideFile] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.ExportGANETPeptideFile
/****************************************************
**
**	Desc: 
**		Creates a flat file containing peptide records
**		for GANET external program
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	grk
**	Date:	04/3/2002
**
**			07/05/2004 mem - Added @JobToExport parameter and modified
**							  for use with new Peptide DB table structure
**			08/10/2004 mem - Added error handling if the bulk copy operation fails
**			09/06/2004 mem - Added GUID unique-ifier to pep_temp filename
**			01/23/2005 mem - Added option to use V_GANET_Peptides or V_GANET_Peptides_Old
**			05/29/2005 mem - Switched to using @TaskID and T_NET_Update_Task_Job_Map to define the jobs to process
**			06/06/2005 mem - Increased size of @S variable
**			07/24/2005 mem - Updated the view to improve its execution speed for databases with very large tables
**			07/27/2005 mem - Updated the export procedure to populate a temporary table with the data to export, then create a view joining the temporary table with T_Dataset_Stats_SIC and T_Dataset_Stats_Scans
**			08/18/2005 mem - Updated to include SIC_Job in the temporary table
**			08/19/2005 mem - Reworked the NET export view to avoid excessive lock requests/second
**			09/30/2005 mem - Switched to using Cleavage_State_Max in T_Sequence rather than a Left Outer Join on T_Peptide_to_Protein_Map
**						   - Switched to using Scan_Time_Peak_Apex in T_Peptides rather than a join into T_Dataset_Stats_SIC and T_Dataset_Stats_Scans
**			11/23/2005 mem - Added brackets around @dbName as needed to allow for DBs with dashes in the name
**			12/12/2005 mem - Updated to support XTandem results
**			01/13/2006 mem - Added an explicit order by list within the BCP call itself
**			07/03/2006 mem - Now using dbo.udfCombinePaths() to combine paths
**			10/10/2008 mem - Added support for Inspect results (type IN_Peptide_Hit)
**			08/23/2011 mem - Added support for MSGFDB results (type MSG_Peptide_Hit)
**			10/25/2011 mem - Now including column MSGF_SpecProb
**			01/06/2012 mem - Updated to use T_Peptides.Job
**			12/05/2012 mem - Added support for MSAlign results (type MSA_Peptide_Hit)
**    
*****************************************************/
(
	@outFileFolderPath varchar(256) = 'F:\GA_Net_Xfer\Out\',	-- Source file folder path
	@outFileName varchar(256) = 'peptideGANET.txt',
	@TaskID int,												-- Corresponds to task in T_NET_Update_Task
	@UsePeakApex tinyint = 1,									-- No longer used; we're now always using the Peak Apex Scan time
	@message varchar(512) = '' output
)
As
	Set NoCount On
	
	Declare @myRowCount int
	Declare @myError int
	Set @myRowCount = 0
	Set @myError = 0

	Set @message = ''

	Declare @TempViewName varchar(100)
	
	-- Define the path to the temporary file used to dump the peptides
	Declare @pepFilePath varchar(512)
	Set @pepFilePath = '"' + dbo.udfCombinePaths(@outFileFolderPath, 'temp_' + Convert(varchar(64), NewID()) + '_' + @outFileName) + '"'

	Declare @outFilePath varchar(512)
	declare @DBName varchar(128)

	Declare @S varchar(7000)
	Declare @OrderBySql varchar(512)
	Declare @OrderBySqlNoPrefix varchar(512)
	Declare @cmd varchar(4000)
	Declare @result int

	--------------------------------------------------------------
	-- build output file path
	--------------------------------------------------------------

	Set @outFilePath = '"' + dbo.udfCombinePaths(@outFileFolderPath, @outFileName) + '"'

	-- Make sure @outFilePath does not exist, deleting it if present
	Set @cmd = 'del ' + @outFilepath
	--
	-- @result will be 1 if @outFilepath didn't exist; that's ok
	EXEC @result = master..xp_cmdshell @cmd, NO_OUTPUT 
	
	/**************************************************************************
	** xp_cmdshell note 
	**
	** When user MTSProc calls this SP, xp_cmdshell will run under the
	** xp_cmdshell Proxy Account.  This account must be created
	** by a system admin using:
	**
	** EXEC sp_xp_cmdshell_proxy_account 'PNL\MTSProc', 'TypePasswordHere';
	**
	** Additionally, when the password for MTSProc changes, this
	** command must be run to update the password
	** 
	**************************************************************************/
	
	--------------------------------------------------------------
	-- Dump the peptides into a temporary file
	-- The simple method is to join V_GANET_Peptides to T_NET_Update_Task_Job_Map
	-- and export the results:
	--   SELECT GP.*
	--   FROM V_GANET_Peptides GP INNER JOIN 
	--        T_NET_Update_Task_Job_Map TJM ON GP.Job = TJM.Job
	--   WHERE TJM.Task_ID = @TaskID
	--
	-- However, this method is extremely inefficient, since Sql Server must
	-- return all of the rows from V_GANET_Peptides then filter the results
	-- to only include the jobs associated with the desired Task_ID
	--
	-- 
	-- So, instead we'll create a custom view with optimized Sql, call BCP,
	-- then delete the view
	--------------------------------------------------------------
 
	Set @TempViewName = 'V_NET_Export_Peptides_Task_' + Convert(varchar(9), @TaskID)

	if exists (select * from dbo.sysobjects where id = object_id(@TempViewName) and OBJECTPROPERTY(id, N'IsView') = 1)
	Begin
		Set @S = 'drop view ' + @TempViewName
		Exec (@S)
	End

	-- Define the Order By Sql since BCP sometimes fails to order the data properly even though the view says to do this
	-- We're specifying this Order By sql both in the view and in the BCP call
	-- Be sure @OrderBySql and @OrderBySqlNoPrefix each starts with a space
	Set @OrderBySql =         ' ORDER BY Pep.Job, Pep.Scan_Number, Pep.Charge_State, Normalized_Score DESC, Pep.Seq_ID'
	Set @OrderBySqlNoPrefix = ' ORDER BY Job, Scan_Number, Charge_State, Normalized_Score DESC, Seq_ID'
	
	set @S = ''
	Set @S = @S + ' CREATE VIEW dbo.' + @TempViewName + ' AS'
	Set @S = @S + ' SELECT TOP 100 PERCENT Pep.Job, Pep.Scan_Number, Seq.Clean_Sequence,'
	Set @S = @S +   ' CASE WHEN Len(IsNull(Seq.Mod_Description, '''')) = 0 THEN ''none'' '
	Set @S = @S +   ' ELSE Seq.Mod_Description END AS Mod_Description, Pep.Seq_ID, Pep.Charge_State,'
	Set @S = @S +   ' CONVERT(real, Pep.MH) AS MH, SS.XCorr AS Normalized_Score, SS.DeltaCn,'
	Set @S = @S +   ' CONVERT(real, SS.Sp) AS Sp, Seq.Cleavage_State_Max, Pep.Scan_Time_Peak_Apex,'
	Set @S = @S +   ' SD.MSGF_SpecProb'
	Set @S = @S + ' FROM T_NET_Update_Task_Job_Map TJM INNER JOIN'
	Set @S = @S +      ' T_Analysis_Description TAD ON TJM.Job = TAD.Job INNER JOIN'
	Set @S = @S +      ' T_Peptides Pep ON Pep.Job = TAD.Job INNER JOIN'
	Set @S = @S +      ' T_Score_Sequest SS ON Pep.Peptide_ID = SS.Peptide_ID INNER JOIN'
	Set @S = @S +      ' T_Sequence Seq ON Pep.Seq_ID = Seq.Seq_ID INNER JOIN'
	Set @S = @S +      ' T_Score_Discriminant SD ON Pep.Peptide_ID = SD.Peptide_ID'
	Set @S = @S + ' WHERE TJM.Task_ID = ' + Convert(varchar(9), @TaskID) + ' AND '
	Set @S = @S +   ' TAD.ResultType = ''Peptide_Hit'''
	Set @S = @S + ' UNION'
	Set @S = @S + ' SELECT TOP 100 PERCENT Pep.Job, Pep.Scan_Number, Seq.Clean_Sequence,'
	Set @S = @S +   ' CASE WHEN Len(IsNull(Seq.Mod_Description, '''')) = 0 THEN ''none'' '
	Set @S = @S +   ' ELSE Seq.Mod_Description END AS Mod_Description, Pep.Seq_ID, Pep.Charge_State,'
	Set @S = @S +   ' CONVERT(real, Pep.MH) AS MH, X.Normalized_Score AS Normalized_Score, 0 AS DeltaCn,'
	Set @S = @S +   ' 500 AS Sp, Seq.Cleavage_State_Max, Pep.Scan_Time_Peak_Apex,'
	Set @S = @S +   ' SD.MSGF_SpecProb'
	Set @S = @S + ' FROM T_NET_Update_Task_Job_Map TJM INNER JOIN'
	Set @S = @S +      ' T_Analysis_Description TAD ON TJM.Job = TAD.Job INNER JOIN'
	Set @S = @S +      ' T_Peptides Pep ON Pep.Job = TAD.Job INNER JOIN'
	Set @S = @S +      ' T_Score_XTandem X ON Pep.Peptide_ID = X.Peptide_ID INNER JOIN'
	Set @S = @S +      ' T_Sequence Seq ON Pep.Seq_ID = Seq.Seq_ID INNER JOIN'
	Set @S = @S +      ' T_Score_Discriminant SD ON Pep.Peptide_ID = SD.Peptide_ID'
	Set @S = @S + ' WHERE TJM.Task_ID = ' + Convert(varchar(9), @TaskID) + ' AND '
	Set @S = @S +   ' TAD.ResultType = ''XT_Peptide_Hit'''
	Set @S = @S + ' UNION'
	Set @S = @S + ' SELECT TOP 100 PERCENT Pep.Job, Pep.Scan_Number, Seq.Clean_Sequence,'
	Set @S = @S +   ' CASE WHEN Len(IsNull(Seq.Mod_Description, '''')) = 0 THEN ''none'' '
	Set @S = @S +   ' ELSE Seq.Mod_Description END AS Mod_Description, Pep.Seq_ID, Pep.Charge_State,'
	Set @S = @S +   ' CONVERT(real, Pep.MH) AS MH, I.Normalized_Score AS Normalized_Score, 0 AS DeltaCn,'
	Set @S = @S +   ' 500 AS Sp, Seq.Cleavage_State_Max, Pep.Scan_Time_Peak_Apex,'
	Set @S = @S +   ' SD.MSGF_SpecProb'
	Set @S = @S + ' FROM T_NET_Update_Task_Job_Map TJM INNER JOIN'
	Set @S = @S +      ' T_Analysis_Description TAD ON TJM.Job = TAD.Job INNER JOIN'
	Set @S = @S +      ' T_Peptides Pep ON Pep.Job = TAD.Job INNER JOIN'
	Set @S = @S +      ' T_Score_Inspect I ON Pep.Peptide_ID = I.Peptide_ID INNER JOIN'
	Set @S = @S +      ' T_Sequence Seq ON Pep.Seq_ID = Seq.Seq_ID INNER JOIN'
	Set @S = @S +      ' T_Score_Discriminant SD ON Pep.Peptide_ID = SD.Peptide_ID'
	Set @S = @S + ' WHERE TJM.Task_ID = ' + Convert(varchar(9), @TaskID) + ' AND '
	Set @S = @S +   ' TAD.ResultType = ''IN_Peptide_Hit'''
	Set @S = @S + ' UNION'
	Set @S = @S + ' SELECT TOP 100 PERCENT Pep.Job, Pep.Scan_Number, Seq.Clean_Sequence,'
	Set @S = @S +   ' CASE WHEN Len(IsNull(Seq.Mod_Description, '''')) = 0 THEN ''none'' '
	Set @S = @S +   ' ELSE Seq.Mod_Description END AS Mod_Description, Pep.Seq_ID, Pep.Charge_State,'
	Set @S = @S +   ' CONVERT(real, Pep.MH) AS MH, M.Normalized_Score AS Normalized_Score, 0 AS DeltaCn,'
	Set @S = @S +   ' 500 AS Sp, Seq.Cleavage_State_Max, Pep.Scan_Time_Peak_Apex,'
	Set @S = @S +   ' SD.MSGF_SpecProb'
	Set @S = @S + ' FROM T_NET_Update_Task_Job_Map TJM INNER JOIN'
	Set @S = @S +      ' T_Analysis_Description TAD ON TJM.Job = TAD.Job INNER JOIN'
	Set @S = @S +      ' T_Peptides Pep ON Pep.Job = TAD.Job INNER JOIN'
	Set @S = @S +      ' T_Score_MSGFDB M ON Pep.Peptide_ID = M.Peptide_ID INNER JOIN'
	Set @S = @S +      ' T_Sequence Seq ON Pep.Seq_ID = Seq.Seq_ID INNER JOIN'
	Set @S = @S +      ' T_Score_Discriminant SD ON Pep.Peptide_ID = SD.Peptide_ID'
	Set @S = @S + ' WHERE TJM.Task_ID = ' + Convert(varchar(9), @TaskID) + ' AND '
	Set @S = @S +   ' TAD.ResultType = ''MSG_Peptide_Hit'''
	Set @S = @S + ' UNION'
	Set @S = @S + ' SELECT TOP 100 PERCENT Pep.Job, Pep.Scan_Number, Seq.Clean_Sequence,'
	Set @S = @S +   ' CASE WHEN Len(IsNull(Seq.Mod_Description, '''')) = 0 THEN ''none'' '
	Set @S = @S +   ' ELSE Seq.Mod_Description END AS Mod_Description, Pep.Seq_ID, Pep.Charge_State,'
	Set @S = @S +   ' CONVERT(real, Pep.MH) AS MH, M.Normalized_Score AS Normalized_Score, 0 AS DeltaCn,'
	Set @S = @S +   ' 500 AS Sp, Seq.Cleavage_State_Max, Pep.Scan_Time_Peak_Apex,'
	Set @S = @S +   ' IsNull(SD.MSGF_SpecProb, M.PValue) AS MSGF_SpecProb'
	Set @S = @S + ' FROM T_NET_Update_Task_Job_Map TJM INNER JOIN'
	Set @S = @S +      ' T_Analysis_Description TAD ON TJM.Job = TAD.Job INNER JOIN'
	Set @S = @S +      ' T_Peptides Pep ON Pep.Job = TAD.Job INNER JOIN'
	Set @S = @S +      ' T_Score_MSAlign M ON Pep.Peptide_ID = M.Peptide_ID INNER JOIN'
	Set @S = @S +      ' T_Sequence Seq ON Pep.Seq_ID = Seq.Seq_ID INNER JOIN'
	Set @S = @S +      ' T_Score_Discriminant SD ON Pep.Peptide_ID = SD.Peptide_ID'
	Set @S = @S + ' WHERE TJM.Task_ID = ' + Convert(varchar(9), @TaskID) + ' AND '
	Set @S = @S +   ' TAD.ResultType = ''MSA_Peptide_Hit'''	
	Set @S = @S + @OrderBySql
	--
	Exec (@S)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	

	Set @DBName = DB_Name()

	-- Use a SQL query against the custom view
	Set @S = 'SELECT * FROM [' + @DBName + '].dbo.' + @TempViewName
	Set @cmd = 'bcp "' + @S + @OrderBySqlNoPrefix + '" queryout ' + @pepFilePath + ' -c -T'
	--
	EXEC @result = master..xp_cmdshell @cmd, NO_OUTPUT 
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		-- Error writing file
		set @message = 'Error exporting data from V_GANET_Peptides to ' + @outFilePath + ' (Error Number ' + Convert(varchar(12), @myError) + ')'
		goto done
	end
	
	--------------------------------------------------------------
	-- Create output file and write out the first line.  
	-- The number on the first line was originally intended to be a "Locker row count", but we never implemented that feature
	--------------------------------------------------------------
	--
	Set @cmd = 'echo 0 > ' + @outFilePath
	--
	EXEC @result = master..xp_cmdshell @cmd, NO_OUTPUT 
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error

	
	--------------------------------------------------------------
	-- append the peptides file to the output file
	--------------------------------------------------------------
	--
	Set @cmd = 'type ' + @pepFilePath + ' >> ' + @outFilePath
	--
	EXEC @result = master..xp_cmdshell @cmd, NO_OUTPUT 
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error

	--------------------------------------------------------------
	-- get rid of temporary peptide file
	--------------------------------------------------------------
	--
	Set @cmd = 'del ' + @pepFilePath
	--
	EXEC @result = master..xp_cmdshell @cmd, NO_OUTPUT 
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error


Done:

	If Len(IsNull(@TempViewName, '')) > 0
	Begin
		-- Delete the temporary view
		Set @S = 'drop view ' + @TempViewName
		Exec (@S)
	End
	
	return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[ExportGANETPeptideFile] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[ExportGANETPeptideFile] TO [MTS_DB_Lite] AS [dbo]
GO

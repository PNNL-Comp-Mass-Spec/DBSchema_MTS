/****** Object:  StoredProcedure [dbo].[LoadSeqInfoAndModsPart1] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure LoadSeqInfoAndModsPart1
/****************************************************
**
**	Desc: 
**		Checks for existence of @PeptideResultToSeqMapFilePath, @PeptideSeqInfoFilePath,
**		  @PeptideSeqModDetailsFilePath, and @PeptideSeqToProteinMapFilePath
**		If all are found, then verifies that the correct number of columns is present in each
**		If the files are valid, then populates temporary tables:
**			#Tmp_Peptide_ResultToSeqMap
**			#Tmp_Peptide_SeqInfo
**			#Tmp_Peptide_ModDetails
**			#Tmp_Peptide_SeqToProteinMap
**
**		Will also populate #Tmp_Peptide_ModSummary if @LoadModSummaryFile = 1
**
**		This procedure works for both Sequest and XTandem and should be called
**		 from LoadSequestPeptidesBulk or LoadXTandemPeptidesBulk.
**
**		Note that this SP requires that the calling procedure create the temporary tables listed above
**
**	Return values:
**		If the _ResultToSeqMap.txt file is not found and @RaiseErrorIfSeqInfoFilesNotFound = 0, 
**		 then this SP will return 0 for @ResultToSeqMapCountLoaded and 0 for @myError.
**
**		If the _ResultToSeqMap.txt files is not found and @RaiseErrorIfSeqInfoFilesNotFound = 1,
**		 then this SP will return 0 for @ResultToSeqMapCountLoaded and 51002 for @myError.
**
**	Auth:	mem
**	Date:	01/25/2006
**			02/14/2006 mem - Added parameterse @PeptideResultToSeqMapFilePath and @PeptideSeqToProteinMapFilePath
**						   - Additionally, now populating tables #Tmp_Peptide_ResultToSeqMap and #Tmp_Peptide_SeqToProteinMap
**			08/26/2008 mem - Added additional logging when LogLevel >= 2
**			10/12/2010 mem - Now setting @myError to 52099 when ValidateDelimitedFile returns a result code = 63
**			12/04/2012 mem - Added parameter @LoadModSummaryFile; now populating #Tmp_Peptide_SeqToProteinMap
**			12/06/2012 mem - Expanded @message to varchar(1024)
**
*****************************************************/
(
	@PeptideResultToSeqMapFilePath varchar(512) = 'F:\Temp\QC_05_2_02Dec05_Pegasus_05-11-13_syn_ResultToSeqMap.txt',
	@PeptideSeqInfoFilePath varchar(512) = 'F:\Temp\QC_05_2_02Dec05_Pegasus_05-11-13_syn_SeqInfo.txt',
	@PeptideSeqModDetailsFilePath varchar(512) = 'F:\Temp\QC_05_2_02Dec05_Pegasus_05-11-13_syn_ModDetails.txt',
	@PeptideSeqToProteinMapFilePath varchar(512) = 'F:\Temp\QC_05_2_02Dec05_Pegasus_05-11-13_syn_SeqToProteinMap.txt',
	@Job int,
	@RaiseErrorIfSeqInfoFilesNotFound tinyint = 1,
	@ResultToSeqMapCountLoaded int=0 output,
	@message varchar(1024)='' output,
	@LoadModSummaryFile tinyint = 0
)
As
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	-- Clear the output parameters
	Set @ResultToSeqMapCountLoaded = 0
	Set @message = ''
	Set @LoadModSummaryFile = IsNull(@LoadModSummaryFile, 0)
	
	Declare @jobStr varchar(12)
	Set @jobStr = cast(@Job as varchar(12))

	Declare @PeptideSeqModSummaryFilePath varchar(512)
	
	Declare @ResultToSeqMapFileExists tinyint
	Declare @SeqInfoFileExists tinyint
	Declare @SeqModDetailsFileExists tinyint
	Declare @SeqModSummaryFileExists tinyint
	Declare @SeqToProteinMapFileExists tinyint

	Declare @ResultToSeqMapColumnCount int
	Declare @SeqInfoColumnCount int
	Declare @SeqModDetailsColumnCount int
	Declare @SeqModSummaryColumnCount int
	Declare @SeqToProteinMapColumnCount int

	Declare @ColumnCountExpected int
	Declare @lineCountToSkip smallint
	Set @lineCountToSkip = 1

	declare @LogLevel int
	declare @LogMessage varchar(512)

	-----------------------------------------------
	-- Lookup the logging level from T_Process_Step_Control
	-----------------------------------------------
	
	Set @LogLevel = 1
	SELECT @LogLevel = enabled
	FROM T_Process_Step_Control
	WHERE (Processing_Step_Name = 'LogLevel')
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	
	
	-----------------------------------------------
	-- Verify that the input files exist and count the number of columns
	-- First check the ResultToSeqMap file, which should have 2 columns
	-----------------------------------------------
	Set @LogMessage = 'Verify the input files and count the number of columns in each'
	if @LogLevel >= 2
		execute PostLogEntry 'Progress', @LogMessage, 'LoadSeqInfoAndModsPart1'

	Set @ColumnCountExpected = 2
	Exec @myError = ValidateDelimitedFile @PeptideResultToSeqMapFilePath, @lineCountToSkip, @ResultToSeqMapFileExists OUTPUT, @ResultToSeqMapColumnCount OUTPUT, @message OUTPUT
	
	-- Note: ValidateDelimitedFile should return 62 if the file does not exist
	if @myError <> 0 AND @myError <> 62
	Begin
		If Len(@message) = 0
			Set @message = 'Error calling ValidateDelimitedFile for ' + @PeptideResultToSeqMapFilePath + ' (Code ' + Convert(varchar(11), @myError) + ')'
		
		if @myError = 63
			-- OpenTextFile was unable to open the file
			-- We need to set the completion code to 9, meaning we want to retry the load
			-- Error code 52099 is used by LoadPeptidesForOneAnalysis
			set @myError = 52099
		else
			Set @myError = 52001

		Goto Done
	End
	else
	Begin
		If @ResultToSeqMapFileExists = 0 Or @ResultToSeqMapColumnCount = 0
		Begin
			-- File does not exist or file is empty; do not proceed
			If @RaiseErrorIfSeqInfoFilesNotFound = 0
			Begin
				-- set @myError to 0 and clear @message since this is not an error
				Set @myError = 0
				Set @message = ''
			End
			Else
			Begin
				If @myError = 0
					Set @myError = 51002
				If Len(@message) = 0
					Set @message = 'ResultToSeqMap file is empty for job ' + @jobStr + ' (' + @PeptideResultToSeqMapFilePath + ')'
			End
			Goto Done
		End
		Else
		Begin
			If @ResultToSeqMapColumnCount < @ColumnCountExpected
			Begin
				Set @message = 'ResultToSeqMap file only contains ' + convert(varchar(11), @ResultToSeqMapColumnCount) + ' columns for job ' + @jobStr + ' (Expecting ' + Convert(varchar(12), @ColumnCountExpected) + ' columns)'
				set @myError = 51003
				Goto Done
			End
		End
	End


	-----------------------------------------------
	-- Now check the SeqInfo file, which should have 4 columns
	-----------------------------------------------
	Set @ColumnCountExpected = 4
	Exec @myError = ValidateDelimitedFile @PeptideSeqInfoFilePath, @lineCountToSkip, @SeqInfoFileExists OUTPUT, @SeqInfoColumnCount OUTPUT, @message OUTPUT
	
	-- Note: ValidateDelimitedFile should return 62 if the file does not exist
	if @myError <> 0 AND @myError <> 62
	Begin
		If Len(@message) = 0
			Set @message = 'Error calling ValidateDelimitedFile for ' + @PeptideSeqInfoFilePath + ' (Code ' + Convert(varchar(11), @myError) + ')'
		
		if @myError = 63
			-- OpenTextFile was unable to open the file
			-- We need to set the completion code to 9, meaning we want to retry the load
			-- Error code 52099 is used by LoadPeptidesForOneAnalysis
			set @myError = 52099
		else
			Set @myError = 52001

		Goto Done
	End
	else
	Begin
		If @SeqInfoFileExists = 0 Or @SeqInfoColumnCount = 0
		Begin
			-- File does not exist or file is empty; do not proceed
			If @RaiseErrorIfSeqInfoFilesNotFound = 0
			Begin
				-- set @myError to 0 and clear @message since this is not an error
				Set @myError = 0
				Set @message = ''
			End
			Else
			Begin
				If @myError = 0
					Set @myError = 51002
				If Len(@message) = 0
					Set @message = 'SeqInfo file is empty for job ' + @jobStr + ' (' + @PeptideSeqInfoFilePath + ')'
			End
			Goto Done
		End
		Else
		Begin
			If @SeqInfoColumnCount < @ColumnCountExpected
			Begin
				Set @message = 'SeqInfo file only contains ' + convert(varchar(11), @SeqInfoColumnCount) + ' columns for job ' + @jobStr + ' (Expecting ' + Convert(varchar(12), @ColumnCountExpected) + ' columns)'
				set @myError = 51003
				Goto Done
			End
		End
	End


	-----------------------------------------------
	-- Now check the ModDetails file, which should have 3 columns
	-- If no peptides are modified, then the ModDetails file will be empty
	-----------------------------------------------
	Set @ColumnCountExpected = 3
	Exec @myError = ValidateDelimitedFile @PeptideSeqModDetailsFilePath, @lineCountToSkip, @SeqModDetailsFileExists OUTPUT, @SeqModDetailsColumnCount OUTPUT, @message OUTPUT
	
	if @myError <> 0
	Begin
		If Len(@message) = 0
			Set @message = 'Error calling ValidateDelimitedFile for ' + @PeptideSeqModDetailsFilePath + ' (Code ' + Convert(varchar(11), @myError) + ')'
		
		if @myError = 63
			-- OpenTextFile was unable to open the file
			-- We need to set the completion code to 9, meaning we want to retry the load
			-- Error code 52099 is used by LoadPeptidesForOneAnalysis
			set @myError = 52099
		else
			Set @myError = 51004

	End
	else
	Begin
		If @SeqModDetailsFileExists = 0 Or @SeqModDetailsColumnCount = 0
		Begin
			-- File does not exist or file is empty; this is OK
			Set @SeqModDetailsFileExists = 0
		End
		Else
		Begin
			If @SeqModDetailsColumnCount < @ColumnCountExpected
			Begin
				Set @message = 'ModDetails file only contains ' + convert(varchar(11), @SeqModDetailsColumnCount) + ' columns for job ' + @jobStr + ' (Expecting ' + Convert(varchar(12), @ColumnCountExpected) + ' columns)'
				set @myError = 51005
				Goto Done
			End
		End
	End

	-----------------------------------------------
	-- Now check the ModSummary file, which should have 6 columns
	-- If no peptides are modified, then the ModSummary file may be empty
	-----------------------------------------------
	If @LoadModSummaryFile = 0
	Begin
		Set @SeqModSummaryFileExists = 0
	End
	Else
	Begin
		Set @PeptideSeqModSummaryFilePath = Replace(@PeptideSeqModDetailsFilePath, '_ModDetails.txt', '_ModSummary.txt')	
		Set @ColumnCountExpected = 6
		Exec @myError = ValidateDelimitedFile @PeptideSeqModSummaryFilePath, @lineCountToSkip, @SeqModSummaryFileExists OUTPUT, @SeqModSummaryColumnCount OUTPUT, @message OUTPUT
		
		if @myError <> 0
		Begin
			If Len(@message) = 0
				Set @message = 'Error calling ValidateDelimitedFile for ' + @PeptideSeqModSummaryFilePath + ' (Code ' + Convert(varchar(11), @myError) + ')'
			
			if @myError = 63
				-- OpenTextFile was unable to open the file
				-- We need to set the completion code to 9, meaning we want to retry the load
				-- Error code 52099 is used by LoadPeptidesForOneAnalysis
				set @myError = 52099
			else
				Set @myError = 51008

		End
		else
		Begin
			If @SeqModSummaryFileExists = 0 Or @SeqModSummaryColumnCount = 0
			Begin
				-- File does not exist or file is empty; this is OK
				Set @SeqModSummaryFileExists = 0
			End
			Else
			Begin
				If @SeqModSummaryColumnCount < @ColumnCountExpected
				Begin
					Set @message = 'ModSummary file only contains ' + convert(varchar(11), @SeqModSummaryColumnCount) + ' columns for job ' + @jobStr + ' (Expecting ' + Convert(varchar(12), @ColumnCountExpected) + ' columns)'
					set @myError = 51009
					Goto Done
				End
			End
		End
	End
	
	-----------------------------------------------
	-- Now check the SeqToProteinMap file, which should have 6 columns
	-----------------------------------------------
	Set @ColumnCountExpected = 6
	Exec @myError = ValidateDelimitedFile @PeptideSeqToProteinMapFilePath, @lineCountToSkip, @SeqToProteinMapFileExists OUTPUT, @SeqToProteinMapColumnCount OUTPUT, @message OUTPUT
	
	-- Note: ValidateDelimitedFile should return 62 if the file does not exist
	if @myError <> 0 AND @myError <> 62
	Begin
		If Len(@message) = 0
			Set @message = 'Error calling ValidateDelimitedFile for ' + @PeptideSeqToProteinMapFilePath + ' (Code ' + Convert(varchar(11), @myError) + ')'
		
		if @myError = 63
			-- OpenTextFile was unable to open the file
			-- We need to set the completion code to 9, meaning we want to retry the load
			-- Error code 52099 is used by LoadPeptidesForOneAnalysis
			set @myError = 52099
		else
			Set @myError = 51001

		Goto Done
	End
	else
	Begin
		If @SeqToProteinMapFileExists = 0 Or @SeqToProteinMapColumnCount = 0
		Begin
			-- File does not exist or file is empty; do not proceed
			If @RaiseErrorIfSeqInfoFilesNotFound = 0
			Begin
				-- set @myError to 0 and clear @message since this is not an error
				Set @myError = 0
				Set @message = ''
			End
			Else
			Begin
				If @myError = 0
					Set @myError = 51002
				If Len(@message) = 0
					Set @message = 'SeqToProteinMap file is empty for job ' + @jobStr + ' (' + @PeptideSeqToProteinMapFilePath + ')'
			End
			Goto Done
		End
		Else
		Begin
			If @SeqToProteinMapColumnCount < @ColumnCountExpected
			Begin
				Set @message = 'SeqToProteinMap file only contains ' + convert(varchar(11), @SeqToProteinMapColumnCount) + ' columns for job ' + @jobStr + ' (Expecting ' + Convert(varchar(12), @ColumnCountExpected) + ' columns)'
				set @myError = 51003
				Goto Done
			End
		End
	End


	-----------------------------------------------
	-- Bulk load contents of ResultToSeqMap file into temporary table
	-- Note that XTandem results files contain a header row so we set FIRSTROW to 2
	-----------------------------------------------
	--
	declare @c nvarchar(2048)

	Set @LogMessage = 'Bulk load contents of the SeqInfo files into temporary tables'
	if @LogLevel >= 2
		execute PostLogEntry 'Progress', @LogMessage, 'LoadSeqInfoAndModsPart1'

	Set @c = 'BULK INSERT #Tmp_Peptide_ResultToSeqMap FROM ' + '''' + @PeptideResultToSeqMapFilePath + ''' WITH (FIRSTROW = 2)'
	exec @myError = sp_executesql @c
	--
	if @myError <> 0
	begin
		set @message = 'Problem executing bulk insert into #Tmp_Peptide_ResultToSeqMap for job ' + @jobStr + '; ' + @c
		Set @myError = 51006
		print @c
		goto Done
	end

	-----------------------------------------------
	-- Populate @ResultToSeqMapCountLoaded
	-----------------------------------------------
	--
	SELECT @ResultToSeqMapCountLoaded = COUNT(*)
	FROM #Tmp_Peptide_ResultToSeqMap
	--
	SELECT @myError = @@error, @myRowCount = @@RowCount

	Set @LogMessage = 'Load complete; loaded ' + Convert(varchar(12), @ResultToSeqMapCountLoaded) + ' entries'
	if @LogLevel >= 2
		execute PostLogEntry 'Progress', @LogMessage, 'LoadSeqInfoAndModsPart1'


	-----------------------------------------------
	-- Bulk load contents of SeqInfo file into temporary table
	-- Note that XTandem results files contain a header row so we set FIRSTROW to 2
	-----------------------------------------------
	--

	Set @c = 'BULK INSERT #Tmp_Peptide_SeqInfo FROM ' + '''' + @PeptideSeqInfoFilePath + ''' WITH (FIRSTROW = 2)'
	exec @myError = sp_executesql @c
	--
	if @myError <> 0
	begin
		set @message = 'Problem executing bulk insert into #Tmp_Peptide_SeqInfo for job ' + @jobStr + '; ' + @c
		Set @myError = 51006
		print @c
		goto Done
	end

	Set @LogMessage = 'Populated #Tmp_Peptide_SeqInfo using ' + @PeptideSeqInfoFilePath
	if @LogLevel >= 2
		execute PostLogEntry 'Progress', @LogMessage, 'LoadSeqInfoAndModsPart1'

	
	-----------------------------------------------
	-- If @SeqModDetailsFileExists > 0, then bulk load contents 
	-- of mod details file into temporary table
	-----------------------------------------------
	--
	If @SeqModDetailsFileExists > 0
	Begin
		Set @c = 'BULK INSERT #Tmp_Peptide_ModDetails FROM ' + '''' + @PeptideSeqModDetailsFilePath + ''' WITH (FIRSTROW = 2)'		
		exec @myError = sp_executesql @c
		--
		if @myError <> 0
		begin
			set @message = 'Problem executing bulk insert into #Tmp_Peptide_ModDetails for job ' + @jobStr + '; ' + @c
			Set @myError = 51007
			print @c
			goto Done
		end

		Set @LogMessage = 'Populated #Tmp_Peptide_ModDetails using ' + @PeptideSeqModDetailsFilePath
		if @LogLevel >= 2
			execute PostLogEntry 'Progress', @LogMessage, 'LoadSeqInfoAndModsPart1'
	end

	-----------------------------------------------
	-- If @SeqModSummaryFileExists > 0, then bulk load contents 
	-- of mod summary file into temporary table
	-----------------------------------------------
	--
	If @SeqModSummaryFileExists > 0
	Begin
		Set @c = 'BULK INSERT #Tmp_Peptide_ModSummary FROM ' + '''' + @PeptideSeqModSummaryFilePath + ''' WITH (FIRSTROW = 2)'
		exec @myError = sp_executesql @c
		--
		if @myError <> 0
		begin
			set @message = 'Problem executing bulk insert into #Tmp_Peptide_ModSummary for job ' + @jobStr + '; ' + @c
			Set @myError = 51010
			print @c
			goto Done
		end

		Set @LogMessage = 'Populated #Tmp_Peptide_ModSummary using ' + @PeptideSeqModSummaryFilePath
		if @LogLevel >= 2
			execute PostLogEntry 'Progress', @LogMessage, 'LoadSeqInfoAndModsPart1'
	end
	

	-----------------------------------------------
	-- Bulk load contents of SeqToProteinMap file into temporary table
	-- Note that XTandem results files contain a header row so we set FIRSTROW to 2
	-----------------------------------------------
	--

	Set @c = 'BULK INSERT #Tmp_Peptide_SeqToProteinMap FROM ' + '''' + @PeptideSeqToProteinMapFilePath + ''' WITH (FIRSTROW = 2)'
	exec @myError = sp_executesql @c
	--
	if @myError <> 0
	begin
		set @message = 'Problem executing bulk insert into #Tmp_Peptide_SeqToProteinMap for job ' + @jobStr + '; ' + @c
		Set @myError = 51006
		print @c
		goto Done
	end

	Set @LogMessage = 'Populated #Tmp_Peptide_SeqToProteinMap using ' + @PeptideSeqToProteinMapFilePath
	if @LogLevel >= 2
		execute PostLogEntry 'Progress', @LogMessage, 'LoadSeqInfoAndModsPart1'


	-----------------------------------------------
	-- Make sure none of the Mod_Descriptions are Null
	-----------------------------------------------
	--
	UPDATE #Tmp_Peptide_SeqInfo
	SET Mod_Description = ''
	WHERE Mod_Description IS NULL
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error


	Set @LogMessage = 'SeqInfo loading complete'
	if @LogLevel >= 2
		execute PostLogEntry 'Progress', @LogMessage, 'LoadSeqInfoAndModsPart1'
	
Done:
	Return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[LoadSeqInfoAndModsPart1] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[LoadSeqInfoAndModsPart1] TO [MTS_DB_Lite] AS [dbo]
GO

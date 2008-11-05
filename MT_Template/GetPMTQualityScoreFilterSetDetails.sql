/****** Object:  StoredProcedure [dbo].[GetPMTQualityScoreFilterSetDetails] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.GetPMTQualityScoreFilterSetDetails
/****************************************************
**
**	Desc:
**		Populates temporary table #FilterSetDetails with the 
**		PMT Quality Score information defined in T_Process_Config
**
**		The calling procedure must create table #FilterSetDetails
**			CREATE TABLE #FilterSetDetails (
**				Filter_Set_Text varchar(256),
**				Filter_Set_ID int NULL,
**				Score_Value real NULL,
**				Experiment_Filter varchar(128) NULL,
**				Instrument_Class_Filter varchar(128) NULL,
**				Unique_Row_ID int Identity(1,1)
**			)
**
**	Return values: 0: success, otherwise, error code
**
**	Auth:	mem
**	Date:	06/08/2007
**			10/16/2007 mem - Added column Instrument_Class_Filter
**		
*****************************************************/
(
	@message varchar(512) = '' output
)
As
	Set nocount on
	
	Declare @myRowCount int	
	Declare @myError int
	Set @myRowCount = 0
	Set @myError = 0
	
	Declare @Continue tinyint

	Set @message = ''
	
	-----------------------------------------------------------
	-- Create the temporary table to hold the Filter Sets to test
	-----------------------------------------------------------
	CREATE TABLE #TmpFilterSetDetailsUnsorted (
		Filter_Set_Text varchar(256),
		Filter_Set_ID int NULL,
		Score_Value real NULL,
		Experiment_Filter varchar(128) NULL,
		Instrument_Class_Filter varchar(128) NULL,
		Unique_Row_ID int Identity(1,1)
	)

	-----------------------------------------------------------
	-- Create the temporary table to hold the parsed values for a given filter set
	-----------------------------------------------------------
	CREATE TABLE #TmpSplitString (
		EntryID int NOT NULL,
		Value varchar(2048) NULL
	)
	
	-----------------------------------------------------------
	-- Populate the table with the Filter Sets
	-----------------------------------------------------------
	INSERT INTO #TmpFilterSetDetailsUnsorted (
		Filter_Set_Text, Score_Value)
	SELECT Value, 1 As ScoreValue
	FROM T_Process_Config
	WHERE [Name] = 'PMT_Quality_Score_Set_ID_and_Value' And Len(Value) > 0
	--
	SELECT @myError = @@error, @myRowCount = @@RowCount
	--
	If @myError <> 0
	Begin
		Set @Message = 'Error populating #TmpFilterSetDetailsUnsorted in ComputePMTQualityScore'
		Goto Done
	End

	-----------------------------------------------------------
	-- Parse the Filter_Set_Text column to split out the Filter_Set_ID
	-- (and possibly Experiment name and/or Instrument Class Filter) from the Score Value
	-----------------------------------------------------------
	Declare @UniqueRowID int
	Declare @CommaLoc int
	
	Declare @FilterSetText varchar(128)
	Declare @FilterSetTextParsed varchar(128)
	Declare @FilterSetValueParsed varchar(128)
	Declare @ExperimentFilterParsed varchar(128)
	Declare @InstrumentClassFilterParsed varchar(128)
	
	Set @UniqueRowID = 0
	Set @Continue = 1
	
	While @Continue > 0
	Begin -- <a>
		Set @FilterSetText = ''
		Set @FilterSetValueParsed = '1'
		Set @ExperimentFilterParsed = ''
		
		SELECT TOP 1 @FilterSetText = IsNull(Filter_Set_Text, ''),
					 @UniqueRowID = Unique_Row_ID
		FROM #TmpFilterSetDetailsUnsorted
		WHERE Unique_Row_ID > @UniqueRowID
		--
		SELECT @myError = @@error, @myRowCount = @@RowCount

		If @myRowCount = 0
			Set @Continue = 0
		Else
		Begin -- <b>
			-- Use udfParseDelimitedListOrdered() to populate a temporary table with the values in @FilterSetText
			TRUNCATE TABLE #TmpSplitString
			
			INSERT INTO #TmpSplitString (EntryID, Value)
			SELECT EntryID, Value
			FROM dbo.udfParseDelimitedListOrdered(@FilterSetText, ',')
			--
			SELECT @myError = @@error, @myRowCount = @@RowCount
			
			-- Define the default values
			Set @FilterSetTextParsed = ''
			Set @FilterSetValueParsed = '1'
			Set @ExperimentFilterParsed = ''
			Set @InstrumentClassFilterParsed = ''
			
			SELECT @FilterSetTextParsed = Value         FROM #TmpSplitString WHERE EntryID = 1
			SELECT @FilterSetValueParsed = Value        FROM #TmpSplitString WHERE EntryID = 2
			SELECT @ExperimentFilterParsed = Value      FROM #TmpSplitString WHERE EntryID = 3
			SELECT @InstrumentClassFilterParsed = Value FROM #TmpSplitString WHERE EntryID = 4
			
			If IsNumeric(@FilterSetTextParsed) = 1 AND IsNumeric(@FilterSetValueParsed) = 1
			Begin
				UPDATE #TmpFilterSetDetailsUnsorted
				SET Filter_Set_ID = Convert(int, @FilterSetTextParsed),
					Score_Value = Convert(real, @FilterSetValueParsed),
					Experiment_Filter = @ExperimentFilterParsed,
					Instrument_Class_Filter = @InstrumentClassFilterParsed
				WHERE Unique_Row_ID = @UniqueRowID
				--
				SELECT @myError = @@error, @myRowCount = @@RowCount
			End
			Else
				Set @myError = 50000
			
			If @myError <> 0
			Begin -- <c>
				-- Invalid filter defined; post message to log, but continue processing
				Set @message = 'Invalid PMT_Quality_Score_Set_ID_and_Value entry in T_Process_Config: ' + @FilterSetText + '; Should be a Filter_Set_ID and filter score value, separated by a comma'
				SELECT @message
				
				execute PostLogEntry 'Error', @message, 'GetPMTQualityScoreFilterSetDetails'
				Set @message = ''
				Set @myError = 0

				DELETE FROM #TmpFilterSetDetailsUnsorted
				WHERE Unique_Row_ID = @UniqueRowID
			End -- </c>
		End -- </b>
	End -- </a>

	-----------------------------------------------------------
	-- Copy the data from #TmpFilterSetDetailsUnsorted to #FilterSetDetails,
	-- sorting on Score_Value
	-----------------------------------------------------------
	
	INSERT INTO #FilterSetDetails (
		Filter_Set_Text, Filter_Set_ID, 
		Score_Value, Experiment_Filter, 
		Instrument_Class_Filter
		)
	SELECT	Filter_Set_Text, Filter_Set_ID, 
			Score_Value, Experiment_Filter, 
			Instrument_Class_Filter
	FROM #TmpFilterSetDetailsUnsorted
	ORDER BY Score_Value, Unique_Row_ID
	--
	SELECT @myError = @@error, @myRowCount = @@RowCount
	
Done:	
	return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[GetPMTQualityScoreFilterSetDetails] TO [MTS_DB_Dev]
GO
GRANT VIEW DEFINITION ON [dbo].[GetPMTQualityScoreFilterSetDetails] TO [MTS_DB_Lite]
GO

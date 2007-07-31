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
**				Unique_Row_ID int Identity(1,1)
**			)
**
**	Return values: 0: success, otherwise, error code
**
**	Auth:	mem
**	Date:	06/08/2007
**		
*****************************************************/
(
	@message varchar(255) = '' output
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
	-- Create the temporary tables to hold the Filter Sets to test
	-----------------------------------------------------------
	CREATE TABLE #FilterSetDetailsUnsorted (
		Filter_Set_Text varchar(256),
		Filter_Set_ID int NULL,
		Score_Value real NULL,
		Experiment_Filter varchar(128) NULL,
		Unique_Row_ID int Identity(1,1)
	)

	-----------------------------------------------------------
	-- Populate the table with the Filter Sets
	-----------------------------------------------------------
	INSERT INTO #FilterSetDetailsUnsorted (
		Filter_Set_Text, Score_Value
		)
	SELECT Value, 1 As ScoreValue
	FROM T_Process_Config
	WHERE [Name] = 'PMT_Quality_Score_Set_ID_and_Value' And Len(Value) > 0
	--
	SELECT @myError = @@error, @myRowCount = @@RowCount
	--
	If @myError <> 0
	Begin
		Set @Message = 'Error populating #FilterSetDetailsUnsorted in ComputePMTQualityScore'
		Goto Done
	End

	-----------------------------------------------------------
	-- Parse the Filter_Set_Text column to split out the Filter_Set_ID
	-- (and possible Experiment name) from the Score Value
	-----------------------------------------------------------
	Declare @UniqueRowID int
	Declare @CommaLoc int
	
	Declare @FilterSetText varchar(128)
	Declare @FilterSetTextParsed varchar(128)
	Declare @FilterSetValueParsed varchar(128)
	Declare @ExperimentFilterParsed varchar(128)
	
	Set @UniqueRowID = 0
	Set @Continue = 1
	
	While @Continue > 0
	Begin
		Set @FilterSetText = ''
		Set @FilterSetValueParsed = '1'
		Set @ExperimentFilterParsed = ''
		
		SELECT TOP 1 @FilterSetText = IsNull(Filter_Set_Text, ''),
					 @UniqueRowID = Unique_Row_ID
		FROM #FilterSetDetailsUnsorted
		WHERE Unique_Row_ID > @UniqueRowID
		--
		SELECT @myError = @@error, @myRowCount = @@RowCount

		If @myRowCount = 0
			Set @Continue = 0
		Else
		 Begin
			Set @CommaLoc = CharIndex(',', @FilterSetText)
			
			If @CommaLoc > 0
			 Begin
				Set @FilterSetTextParsed = LTrim(RTrim(SubString(@FilterSetText, 1, @CommaLoc-1)))
				Set @FilterSetValueParsed = LTrim(RTrim(SubString(@FilterSetText, @CommaLoc+1, Len(@FilterSetText) - @CommaLoc)))

				Set @CommaLoc = CharIndex(',', @FilterSetValueParsed)
				
				If @CommaLoc > 0
				Begin
					Set @ExperimentFilterParsed = LTrim(RTrim(SubString(@FilterSetValueParsed, @CommaLoc+1, Len(@FilterSetValueParsed) - @CommaLoc)))
					Set @FilterSetValueParsed = LTrim(RTrim(SubString(@FilterSetValueParsed, 1, @CommaLoc-1)))
				End
				Else
				Begin
					set @FilterSetValueParsed = LTrim(RTrim(@FilterSetValueParsed))
					Set @ExperimentFilterParsed = ''
				End
			 End
			Else
			 Begin
				Set @FilterSetTextParsed = LTrim(RTrim(@FilterSetText))
				Set @FilterSetValueParsed = '1'
				Set @ExperimentFilterParsed = ''
			 End
			
			If IsNumeric(@FilterSetTextParsed) = 1 AND IsNumeric(@FilterSetValueParsed) = 1
			 Begin
				UPDATE #FilterSetDetailsUnsorted
				SET Filter_Set_ID = Convert(int, @FilterSetTextParsed),
					Score_Value = Convert(real, @FilterSetValueParsed),
					Experiment_Filter = @ExperimentFilterParsed
				WHERE Unique_Row_ID = @UniqueRowID
				--
				SELECT @myError = @@error, @myRowCount = @@RowCount
			 End
			Else
				Set @myError = 50000
			
			If @myError <> 0
			Begin
				-- Invalid filter defined; post message to log, but continue processing
				Set @message = 'Invalid PMT_Quality_Score_Set_ID_and_Value entry in T_Process_Config: ' + @FilterSetText + '; Should be a Filter_Set_ID and filter score value, separated by a comma'
				SELECT @message
				
				execute PostLogEntry 'Error', @message, 'GetPMTQualityScoreFilterSetDetails'
				Set @message = ''
				Set @myError = 0

				DELETE FROM #FilterSetDetailsUnsorted
				WHERE Unique_Row_ID = @UniqueRowID
			End
		 End		
	End

	-----------------------------------------------------------
	-- Copy the data from #FilterSetDetailsUnsorted to #FilterSetDetails,
	-- sorting on Score_Value
	-----------------------------------------------------------
	
	INSERT INTO #FilterSetDetails (Filter_Set_Text, Filter_Set_ID, Score_Value, Experiment_Filter)
	SELECT Filter_Set_Text, Filter_Set_ID, Score_Value, Experiment_Filter
	FROM #FilterSetDetailsUnsorted
	ORDER BY Score_Value, Unique_Row_ID
	--
	SELECT @myError = @@error, @myRowCount = @@RowCount
	
Done:	
	return @myError


GO

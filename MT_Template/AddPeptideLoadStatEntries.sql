/****** Object:  StoredProcedure [dbo].[AddPeptideLoadStatEntries] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.AddPeptideLoadStatEntries
/****************************************************
**
**	Desc: 
**		Calls AddPeptideLoadStatEntry to populate T_Peptide_Load_Stats for each 
**		value of 'Peptide_Load_Stats_Detail_Thresholds' defined in T_Process_Config
**
**	Return values: 0 if no error; otherwise error code
**
**	Auth:	mem
**	Date:	09/07/2007
**			02/26/2008 mem - Added call to VerifyUpdateEnabled
**    
*****************************************************/
(
	@AnalysisStateMatch int = 7,
	@InfoOnly tinyint = 0,
	@JobDateMax datetime = '12/31/9999'			-- Ignored if >= '12/31/9999'
)
AS
	set nocount on

	Declare @myRowCount int
	Declare @myError int
	set @myRowCount = 0
	set @myError = 0
	
	Declare @continue int
	Declare @ProcessConfigIDCurrent int
	Declare @SortIndexCurrent int
	
	Declare @ScoreThresholds varchar(255)
	Declare @CommaLoc int
	
	Declare @DiscriminantScoreMinimum real
	Declare @PeptideProphetMinimum real
	
	Declare @message varchar(255)
	Declare @UpdateEnabled tinyint
	
	-----------------------------------------------------
	-- Validate the inputs
	-----------------------------------------------------

	CREATE TABLE #Tmp_ScoreThresholds (
		UniqueID int NOT NULL Identity(1,1),
		DiscriminantScoreMinimum real NOT NULL,
		PeptideProphetMinimum real NOT NULL,
		SortOrder int NULL
	)
	
	-----------------------------------------------------
	-- Populate #Tmp_ScoreThresholds using the values in T_Process_Config
	-----------------------------------------------------
	
	Set @ProcessConfigIDCurrent = -1
	Set @continue = 1
	While @continue = 1
	Begin -- <a>
		SELECT TOP 1 @ProcessConfigIDCurrent = Process_Config_ID, 
					 @ScoreThresholds = Value
		FROM T_Process_Config
		WHERE ([Name] = 'Peptide_Load_Stats_Detail_Thresholds') AND
			  Process_Config_ID > @ProcessConfigIDCurrent
		ORDER BY Process_Config_ID
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		
		If @myRowCount = 0
			Set @continue = 0
		Else
		Begin -- <b>
			-- Split @ScoreThresholds on the comma
			Set @ScoreThresholds = IsNull(@ScoreThresholds, '')
			Set @CommaLoc = CharIndex(',', @ScoreThresholds)
			
			If @CommaLoc <= 0
			Begin
				Set @message = 'Comma not found in Threshold values defined for Process_Config_ID entry ' + Convert(varchar(12), @ProcessConfigIDCurrent) + ': ' + @ScoreThresholds
				If @InfoOnly = 0
					execute PostLogEntry 'Error', @message, 'AddPeptideLoadStatEntries'
				Else
					SELECT @message as Error_Message
			End
			Else
			Begin -- <c>
				-- @ScoreThresholds should contain two values, separated by a comma
				-- Split them out and store in @DiscriminantScoreMinimum & @PeptideProphetMinimum
				
				Begin Try
					Set @DiscriminantScoreMinimum = Convert(real, Substring(@ScoreThresholds, 1, @CommaLoc-1))
					Set @PeptideProphetMinimum = Convert(real, Substring(@ScoreThresholds, @CommaLoc+1, Len(@ScoreThresholds)))
					
					INSERT INTO #Tmp_ScoreThresholds (DiscriminantScoreMinimum, PeptideProphetMinimum) 
					VALUES (@DiscriminantScoreMinimum, @PeptideProphetMinimum)
					--
					SELECT @myRowCount = @@rowcount, @myError = @@error
					
				End Try
				Begin Catch
					Set @message = 'Error parsing out Discriminant and Peptide Prophet score thresholds from Process_Config_ID entry ' + Convert(varchar(12), @ProcessConfigIDCurrent) + ': ' + @ScoreThresholds + '; ' + IsNull(ERROR_MESSAGE(), '')
					If @InfoOnly = 0
						execute PostLogEntry 'Error', @message, 'AddPeptideLoadStatEntries'
					Else
						SELECT @message as Error_Message
				End Catch
				
				set @message= ''
			End	 -- </c>		
			
		End	 -- </b>
	End -- </a>

	-----------------------------------------------------
	-- See if #Tmp_ScoreThresholds is empty
	-----------------------------------------------------
	--
	Set @myRowCount = 0
	SELECT @myRowCount = COUNT(*)
	FROM #Tmp_ScoreThresholds
	
	If @myRowCount = 0
	Begin
		-- Score values not found; define two peptide prophet minima by default
		
		INSERT INTO #Tmp_ScoreThresholds (DiscriminantScoreMinimum, PeptideProphetMinimum) 
		VALUES (0, 0.5)

		INSERT INTO #Tmp_ScoreThresholds (DiscriminantScoreMinimum, PeptideProphetMinimum) 
		VALUES (0, 0.9)
		
	End
	
	-----------------------------------------------------
	-- Populate the SortOrder column in #Tmp_ScoreThresholds
	-----------------------------------------------------
	--
	UPDATE #Tmp_ScoreThresholds
	SET SortOrder = SortOrderQ.SortOrderNew
	FROM #Tmp_ScoreThresholds ST INNER JOIN 
		 ( SELECT UniqueID,
                  ROW_NUMBER() OVER ( ORDER BY PeptideProphetMinimum, DiscriminantScoreMinimum ) AS SortOrderNew
	       FROM #Tmp_ScoreThresholds 
	     ) SortOrderQ ON ST.UniqueID = SortOrderQ.UniqueID
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error

	
	-----------------------------------------------------
	-- Call AddPeptideLoadStatEntry for each entry in #Tmp_ScoreThresholds
	-----------------------------------------------------

	Set @SortIndexCurrent = -1
	Set @continue = 1
	While @continue = 1
	Begin

		-- Validate that updating is enabled, abort if not enabled (but allow pausing)
		exec VerifyUpdateEnabled @CallingFunctionDescription = 'AddPeptideLoadStatEntries', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
		If @UpdateEnabled = 0
			Goto Done

		SELECT TOP 1 @SortIndexCurrent = SortOrder,
					 @DiscriminantScoreMinimum = DiscriminantScoreMinimum,
					 @PeptideProphetMinimum = PeptideProphetMinimum
		FROM #Tmp_ScoreThresholds
		WHERE SortOrder > @SortIndexCurrent
		ORDER BY SortOrder		
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		
		If @myRowCount = 0
			Set @continue = 0
		Else
		Begin
			Exec @myError = AddPeptideLoadStatEntry @DiscriminantScoreMinimum, @PeptideProphetMinimum, @AnalysisStateMatch, @InfoOnly, @JobDateMax
			
			If @myError <> 0
				Goto Done
		End
	End
	
Done:
	Return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[AddPeptideLoadStatEntries] TO [MTS_DB_Dev]
GO
GRANT VIEW DEFINITION ON [dbo].[AddPeptideLoadStatEntries] TO [MTS_DB_Lite]
GO

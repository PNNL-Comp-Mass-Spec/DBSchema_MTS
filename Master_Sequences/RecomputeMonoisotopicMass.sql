/****** Object:  StoredProcedure [dbo].[RecomputeMonoisotopicMass] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[RecomputeMonoisotopicMass]
/****************************************************
**
**	Desc:	Recomputes the monoisotopic mass values in T_Sequence for sequences
**			matching the given Seq_ID range and/or containing the given Mass_Correction_Tag in T_Mod_Descriptors
**
**			Updates T_Seq_Mass_Update_History with any changes made
**
**	Return values: 0: success, otherwise, error code
**
**	Auth:	mem
**	Date:	07/28/2006
**          04/11/2020 mem - Expand Mass_Correction_Tag to varchar(32)
**
*****************************************************/
(
	@SeqIDMin int = 0,
	@SeqIDMax int = 0,								-- If 0, then no maximum is used
	@MassCorrectionTagList varchar(128)='',			-- Single mass correction tag or list of mass correction tags (wildcards not allowed), e.g. 'Ubiq_02 '
	@message varchar(256) = '' output
)
As
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	Declare @MatchSpec varchar(128)

	-------------------------------------------------
	-- Validate the inputs
	-------------------------------------------------
	set @message = ''
	Set @SeqIDMin = IsNull(@SeqIDMin, 0)
	Set @SeqIDMax = IsNull(@SeqIDMax, 0)
	Set @MassCorrectionTagList = LTrim(RTrim(IsNull(@MassCorrectionTagList, '')))

	If @SeqIDMin <= 0 And @SeqIDMax <= 0 And Len(@MassCorrectionTagList) = 0
	Begin
		Set @Message = 'Must define a SeqID range and/or define a Mass Correction tag to match'
		Set @myError = 20000
		Goto Done
	End

	-------------------------------------------------
	-- Update @SeqIDMax if it is currently 0
	-------------------------------------------------
	If @SeqIDMax = 0
		Set @SeqIDMax = 2147483647

	-------------------------------------------------
	-- Determine the next available @BatchID
	-------------------------------------------------
	Declare @BatchID int
	Set @BatchID = 0
	SELECT @BatchID = MAX(Batch_ID)
	FROM T_Seq_Mass_Update_History

	Set @BatchID = IsNull(@BatchID, 0) + 1

	-------------------------------------------------
	-- Find matching sequences
	-------------------------------------------------
	If Len(@MassCorrectionTagList) > 0
	Begin
		CREATE TABLE #T_Tmp_MassCorrectionTags (
			Mass_Correction_Tag varchar(32)
		)

		INSERT INTO #T_Tmp_MassCorrectionTags (Mass_Correction_Tag)
		SELECT Value
		FROM dbo.udfParseDelimitedList(@MassCorrectionTagList, ',')
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		INSERT INTO T_Seq_Mass_Update_History (Batch_ID, Seq_ID, Monoisotopic_Mass_Old, Update_Date)
		SELECT DISTINCT @BatchID, T_Sequence.Seq_ID, T_Sequence.Monoisotopic_Mass, GetDate()
		FROM T_Sequence INNER JOIN T_Mod_Descriptors ON
			 T_Sequence.Seq_ID = T_Mod_Descriptors.Seq_ID
			 INNER JOIN #T_Tmp_MassCorrectionTags ON
			 T_Mod_Descriptors.Mass_Correction_Tag = #T_Tmp_MassCorrectionTags.Mass_Correction_Tag
		WHERE T_Sequence.Seq_ID >= @SeqIDMin AND T_Sequence.Seq_ID <= @SeqIDMax
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		Set @MatchSpec = '@SeqID between ' + Convert(varchar(12), @SeqIDMin) + ' and ' + Convert(varchar(12), @SeqIDMax) + ' and Mass_Correction_Tag In "' + @MassCorrectionTagList + '"'
	End
	Else
	Begin
		INSERT INTO T_Seq_Mass_Update_History (Batch_ID, Seq_ID, Monoisotopic_Mass_Old)
		SELECT @BatchID, Seq_ID, Monoisotopic_Mass
		FROM T_Sequence
		WHERE Seq_ID >= @SeqIDMin AND Seq_ID <= @SeqIDMax
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		Set @MatchSpec = '@SeqID between ' + Convert(varchar(12), @SeqIDMin) + ' and ' + Convert(varchar(12), @SeqIDMax)
	End

	If @myError <> 0
	Begin
		Set @message = 'Error populating T_Seq_Mass_Update_History with sequences matching ' + @MatchSpec
		Set @myError = 20001
	End

	If @myRowCount = 0
	Begin
		Set @message = 'Match not found for ' + @MatchSpec
		Set @myError = 20002
		Goto Done
	End

	-------------------------------------------------
	-- Post a progress message to the log
	-------------------------------------------------
	Set @message = 'T_Seq_Mass_Update_History.Batch_ID ' + Convert(varchar(9), @BatchID) + ' has ' + Convert(varchar(12), @myRowCount) + ' sequences with ' + @MatchSpec
	exec PostLogEntry 'Progress', @message, 'RecomputeMonoisotopicMass'
	Set @message = ''

	-------------------------------------------------
	-- Set the masses for the matching sequences to Null
	-------------------------------------------------
	UPDATE T_Sequence
	SET Monoisotopic_Mass = NULL, last_affected = GetDate()
	FROM T_Seq_Mass_Update_History INNER JOIN T_Sequence ON
		 T_Seq_Mass_Update_History.Seq_ID = T_Sequence.Seq_ID
	WHERE T_Seq_Mass_Update_History.Batch_ID = @BatchID
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	If @myError <> 0
	Begin
		Set @message = 'Error resetting masses to Null for the sequences associated with T_Seq_Mass_Update_History.Batch_ID ' + Convert(varchar(9), @BatchID)
		Set @myError = 20003
	End

	Set @message = 'Mass values set to Null for the ' + Convert(varchar(12), @myRowCount)  + ' sequences associated with T_Seq_Mass_Update_History.Batch_ID ' + Convert(varchar(9), @BatchID)
	exec PostLogEntry 'Progress', @message, 'RecomputeMonoisotopicMass'
	Set @message = ''


	-------------------------------------------------
	-- Compute the masses
	-------------------------------------------------
	Declare @PeptidesProcessedCount int

	Set @message = ''
	Set @PeptidesProcessedCount = 0
	Exec @PeptidesProcessedCount = CalculateMonoisotopicMass @message OUTPUT

	If Len(@message) > 0
		exec PostLogEntry 'Error', @message, 'RecomputeMonoisotopicMass'
	Else
	Begin
		Set @message = 'Done recomputing mass values for the sequences associated with T_Seq_Mass_Update_History.Batch_ID ' + Convert(varchar(9), @BatchID)
		exec PostLogEntry 'Progress', @message, 'RecomputeMonoisotopicMass'
	End


	-------------------------------------------------
	-- Update Monoisotopic_Mass_New
	-------------------------------------------------
	UPDATE T_Seq_Mass_Update_History
	SET Monoisotopic_Mass_New = T_Sequence.Monoisotopic_Mass,
		Update_Date = GetDate()
	FROM T_Seq_Mass_Update_History INNER JOIN T_Sequence ON
		 T_Seq_Mass_Update_History.Seq_ID = T_Sequence.Seq_ID AND
		 T_Seq_Mass_Update_History.Batch_ID = @BatchID
	WHERE NOT T_Sequence.Monoisotopic_Mass Is Null
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	set @message = 'Recomputed the masses for ' + Convert(varchar(12), @myRowCount) + ' rows in T_Sequence associated with T_Seq_Mass_Update_History.Batch_ID ' + Convert(varchar(9), @BatchID)
	exec PostLogEntry 'Normal', @message, 'RecomputeMonoisotopicMass'

Done:

	If @myError <> 0
		Select @Message as TheMessage, @myError as TheError

	Return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[RecomputeMonoisotopicMass] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[RecomputeMonoisotopicMass] TO [MTS_DB_Lite] AS [dbo]
GO

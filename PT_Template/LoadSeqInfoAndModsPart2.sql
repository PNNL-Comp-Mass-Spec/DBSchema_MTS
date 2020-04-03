/****** Object:  StoredProcedure [dbo].[LoadSeqInfoAndModsPart2] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.LoadSeqInfoAndModsPart2
/****************************************************
**
**	Desc:
**		Load sequence info and mod details into sequence
**		 candidate tables for given analysis job
**
**		This SP also requires that the calling procedure create and populate these
**		 temporary tables (see LoadSeqInfoAndModsPart1 and LoadSequestPeptidesBulk/LoadXTandemPeptidesBulk):
**			#Tmp_Peptide_Import
**			#Tmp_Unique_Records
**			#Tmp_Peptide_ResultToSeqMap
**			#Tmp_Peptide_SeqInfo
**			#Tmp_Peptide_ModDetails
**			#Tmp_Peptide_ModSummary
**
**		This procedure works for both Sequest and XTandem and should be called
**		from LoadSequestPeptidesBulk or LoadXTandemPeptidesBulk.
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	01/25/2006
**			02/14/2006 mem - Updated to use tables #Tmp_Peptide_ResultToSeqMap in addition to tables #Tmp_Peptide_SeqInfo and #Tmp_Peptide_ModDetails
**			06/28/2006 mem - Now checking for negative Position values in #Tmp_Peptide_ModDetails
**			08/26/2008 mem - Added additional logging when LogLevel >= 2
**			01/06/2012 mem - Updated to use T_Peptides.Job
**			12/05/2012 mem - Now populating T_Seq_Candidate_ModSummary using #Tmp_Peptide_ModSummary
**          04/09/2020 mem - Expand Mass_Correction_Tag to varchar(32)
**
*****************************************************/
(
	@Job int,
	@message varchar(512)='' output
)
As
	Set NoCount On

	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	-- Clear the output parameters
	Set @message = ''

	Declare @jobStr varchar(12)
	Set @jobStr = cast(@Job as varchar(12))

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

	Set @LogMessage = 'Populating T_Seq_Candidates using #Tmp_Peptide_Import, #Tmp_Unique_Records, and the SeqInfo tables'
	if @LogLevel >= 2
		execute PostLogEntry 'Progress', @LogMessage, 'LoadSeqInfoAndModsPart2'

	-----------------------------------------------
	-- Make sure the Seq_Candidate tables do not have any data for this job
	-----------------------------------------------
	--
	DELETE FROM T_Seq_Candidate_to_Peptide_Map Where Job = @Job
	DELETE FROM T_Seq_Candidate_ModDetails	 Where Job = @Job
	DELETE FROM T_Seq_Candidates Where Job = @Job
	DELETE FROM T_Seq_Candidate_ModSummary Where Job = @Job


	-----------------------------------------------
	-- Insert new data into T_Seq_Candidates
	-- Link into #Tmp_Peptide_Import, #Tmp_Unique_Records,
	--  and the SeqInfo tables to obtain the candidate sequences;
	--  We have to use Group By statements since peptides can be present in
	--  #Tmp_Peptide_Import multiple times
	-----------------------------------------------
	--
	INSERT INTO T_Seq_Candidates
		(Job, Seq_ID_Local, Clean_Sequence, Mod_Count, Mod_Description, Monoisotopic_Mass)
	SELECT	@Job AS Job, TPS.Seq_ID_Local,
			MAX(dbo.udfCleanSequence(TPI.Peptide)) AS Peptide,
			TPS.Mod_Count, TPS.Mod_Description,
			MAX(TPS.Monoisotopic_Mass) AS Monoisotopic_Mass
	FROM #Tmp_Unique_Records UR INNER JOIN
		 #Tmp_Peptide_Import TPI ON UR.Result_ID = TPI.Result_ID INNER JOIN
		 #Tmp_Peptide_ResultToSeqMap RTSM ON TPI.Result_ID = RTSM.Result_ID INNER JOIN
		 #Tmp_Peptide_SeqInfo TPS ON RTSM.Seq_ID_Local = TPS.Seq_ID_Local
	GROUP BY TPS.Seq_ID_Local, TPS.Mod_Count, TPS.Mod_Description
	ORDER BY TPS.Seq_ID_Local
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Error inserting into T_Seq_Candidates for job ' + @jobStr
		goto Done
	end

	Set @LogMessage = 'Populated T_Seq_Candidates with ' + Convert(varchar(12), @myRowCount) + ' rows'
	if @LogLevel >= 2
		execute PostLogEntry 'Progress', @LogMessage, 'LoadSeqInfoAndModsPart2'


	-----------------------------------------------
	-- Insert new data into T_Seq_Candidate_to_Peptide_Map
	-----------------------------------------------
	--
	INSERT INTO T_Seq_Candidate_to_Peptide_Map
		(Job, Seq_ID_Local, Peptide_ID)
	SELECT @Job AS Job, RTSM.Seq_ID_Local, UR.Peptide_ID_New
	FROM #Tmp_Unique_Records UR INNER JOIN
		 #Tmp_Peptide_Import TPI ON UR.Result_ID = TPI.Result_ID INNER JOIN
		 #Tmp_Peptide_ResultToSeqMap RTSM ON TPI.Result_ID = RTSM.Result_ID
	ORDER BY UR.Peptide_ID_New
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Error inserting into T_Seq_Candidate_to_Peptide_Map for job ' + @jobStr
		goto Done
	end

	Set @LogMessage = 'Populated T_Seq_Candidate_to_Peptide_Map with ' + Convert(varchar(12), @myRowCount) + ' rows'
	if @LogLevel >= 2
		execute PostLogEntry 'Progress', @LogMessage, 'LoadSeqInfoAndModsPart2'


	-- Keep track of the number of entries added to T_Seq_Candidate_to_Peptide_Map
	Declare @numAddedPeptides int
	Set @numAddedPeptides = @myRowCount

	-----------------------------------------------
	-- See if any entries in #Tmp_Peptide_ModDetails have
	-- negative Position values (which previuosly were used to signify
	-- peptide or protein terminus mods)
	-- If any are found, abort the load and post an entry to the log
	-----------------------------------------------
	Declare @MatchCount int

	Set @MatchCount = 0
	SELECT @MatchCount = COUNT(*)
	FROM #Tmp_Peptide_ModDetails
	WHERE [Position] < 0
	--
	If @MatchCount > 0
	Begin
		Set @myError = 51009
		set @message = 'Found negative Mod Position values for job ' + @jobStr + ' (' + Convert(varchar(12), @MatchCount) + ' negative values); aborting load'
		goto Done
	End


	-----------------------------------------------
	-- See if any entries in #Tmp_Peptide_ModDetails have
	--  Mass_Correction_Tag entries over 32 characters in length
	-- If any are found, truncate to 32 characters and post an entry to the log
	-----------------------------------------------

	Set @MatchCount = 0
	SELECT @MatchCount = COUNT(*)
	FROM #Tmp_Peptide_ModDetails
	WHERE (LEN(LTrim(RTrim(Mass_Correction_Tag))) > 32)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Error looking for long Mass_Correction_Tags in #Tmp_Peptide_ModDetails for job ' + @jobStr
		goto Done
	end

	If @MatchCount > 0
	Begin
		set @message = 'Found ' + Convert(varchar(12), @MatchCount) + ' Mass_Correction_Tags with a length over 32 characters in #Tmp_Peptide_ModDetails for job ' + @jobStr + '; truncating to a maximum length of 32 characters'
		execute PostLogEntry 'Error', @message, 'LoadSeqInfoAndModsPart2'
		set @message = ''

		UPDATE #Tmp_Peptide_ModDetails
		SET Mass_Correction_Tag = Left(LTrim(RTrim(Mass_Correction_Tag)), 32)
		FROM #Tmp_Peptide_ModDetails
		WHERE (LEN(LTrim(RTrim(Mass_Correction_Tag))) > 32)
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
	End

	Set @LogMessage = 'Verified the data in #Tmp_Peptide_ModDetails'
	if @LogLevel >= 2
		execute PostLogEntry 'Progress', @LogMessage, 'LoadSeqInfoAndModsPart2'

	-----------------------------------------------
	-- Insert new data into T_Seq_Candidate_ModDetails
	-- We're linking into T_Seq_Candidates here to
	-- limit the data loaded to only be for those peptides
	-- that passed the import filters
	-----------------------------------------------
	--
	INSERT INTO T_Seq_Candidate_ModDetails
		(Job, Seq_ID_Local, Mass_Correction_Tag, [Position])
	SELECT @Job AS Job, SCMD.Seq_ID_Local,
		   SCMD.Mass_Correction_Tag, SCMD.[Position]
	FROM #Tmp_Peptide_ModDetails SCMD
	     INNER JOIN T_Seq_Candidates SC
	       ON SCMD.Seq_ID_Local = SC.Seq_ID_Local AND
	          SC.Job = @Job
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Error inserting into T_Seq_Candidate_ModDetails for job ' + @jobStr
		goto Done
	end

	Set @LogMessage = 'Populated T_Seq_Candidate_ModDetails with ' + Convert(varchar(12), @myRowCount) + ' rows'
	if @LogLevel >= 2
		execute PostLogEntry 'Progress', @LogMessage, 'LoadSeqInfoAndModsPart2'

	-----------------------------------------------
	-- Insert new data into T_Seq_Candidate_ModSummary
	-- We're linking into T_Seq_Candidates here to
	-- limit the data loaded to only be for those peptides
	-- that passed the import filters
	-----------------------------------------------
	--
	INSERT INTO T_Seq_Candidate_ModSummary
		(Job, Modification_Symbol, Modification_Mass, Target_Residues, Modification_Type, Mass_Correction_Tag, Occurrence_Count)
	SELECT Job,
	       Modification_Symbol,
	       Modification_Mass,
	       Target_Residues,
	       Modification_Type,
	       Mass_Correction_Tag,
	       Occurrence_Count
	FROM ( SELECT @Job AS Job,
	              SCMS.Modification_Symbol,
	              SCMS.Modification_Mass,
	              SCMS.Target_Residues,
	              SCMS.Modification_Type,
	              SCMS.Mass_Correction_Tag,
	              SCMS.Occurrence_Count,
	              Row_Number() OVER ( Partition BY SC.Job, SCMS.Mass_Correction_Tag ORDER BY SCMS.Occurrence_Count Desc) AS TagRank
	       FROM #Tmp_Peptide_ModDetails SCMD
	            INNER JOIN T_Seq_Candidates SC
	              ON SCMD.Seq_ID_Local = SC.Seq_ID_Local AND
	                 SC.Job = @Job
	            INNER JOIN #Tmp_Peptide_ModSummary SCMS
	              ON SCMD.Mass_Correction_Tag = SCMS.Mass_Correction_Tag
	     ) RankQ
	WHERE TagRank = 1
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Error inserting into T_Seq_Candidate_ModSummary for job ' + @jobStr
		goto Done
	end

	Set @LogMessage = 'Populated T_Seq_Candidate_ModSummary with ' + Convert(varchar(12), @myRowCount) + ' rows'
	if @LogLevel >= 2
		execute PostLogEntry 'Progress', @LogMessage, 'LoadSeqInfoAndModsPart2'

	-----------------------------------------------
	-- Make sure the number of rows inserted equals the number of rows in T_Peptides for this job
	-----------------------------------------------
	Declare @numPeptidesExpected int
	Set @numPeptidesExpected = 0

	SELECT @numPeptidesExpected = COUNT(*)
	FROM T_Peptides
	WHERE Job = @Job
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Error counting peptides in T_Peptides for job ' + @jobStr
		goto Done
	end
	--
	if @numPeptidesExpected <> @numAddedPeptides
	begin
		-- Peptide counts do not agree; raise an error
		set @message = 'Number of peptides in T_Peptides does not agree with number in T_Seq_Candidate_to_Peptide_Map for job ' + @jobStr + ' (' + Convert(varchar(12), @numPeptidesExpected) + ' vs. ' + Convert(varchar(12), @numAddedPeptides) + ')'
		Set @myError = 51008
		goto Done
	end


Done:
	Return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[LoadSeqInfoAndModsPart2] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[LoadSeqInfoAndModsPart2] TO [MTS_DB_Lite] AS [dbo]
GO

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
	--  Mass_Correction_Tag entries over 8 characters in length
	-- If any are found, truncate to 8 characters and post an entry to the log
	-----------------------------------------------
	
	Set @MatchCount = 0
	SELECT @MatchCount = COUNT(*)
	FROM #Tmp_Peptide_ModDetails
	WHERE (LEN(LTrim(RTrim(Mass_Correction_Tag))) > 8)
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
		set @message = 'Found ' + Convert(varchar(12), @MatchCount) + ' Mass_Correction_Tags with a length over 8 characters in #Tmp_Peptide_ModDetails for job ' + @jobStr + '; truncating to a maximum length of 8 characters'
		execute PostLogEntry 'Error', @message, 'LoadSeqInfoAndModsPart2'
		set @message = ''

		UPDATE #Tmp_Peptide_ModDetails
		SET Mass_Correction_Tag = Left(LTrim(RTrim(Mass_Correction_Tag)), 8)
		FROM #Tmp_Peptide_ModDetails
		WHERE (LEN(LTrim(RTrim(Mass_Correction_Tag))) > 8)
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
	End
	
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
	FROM #Tmp_Peptide_ModDetails SCMD INNER JOIN
		 T_Seq_Candidates SC ON SCMD.Seq_ID_Local = SC.Seq_ID_Local AND SC.Job = @Job
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Error inserting into T_Seq_Candidate_ModDetails for job ' + @jobStr
		goto Done
	end
		

	-----------------------------------------------
	-- Make sure the number of rows inserted equals the number of rows in T_Peptides for this job
	-----------------------------------------------
	Declare @numPeptidesExpected int
	Set @numPeptidesExpected = 0
	
	SELECT @numPeptidesExpected = COUNT(*)
	FROM T_Peptides
	WHERE Analysis_ID = @Job
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
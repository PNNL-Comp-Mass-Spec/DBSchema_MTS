/****** Object:  StoredProcedure [dbo].[UpdatePeptideStateID] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.UpdatePeptideStateID
/****************************************************
**
**	Desc:	Updates column State_ID in T_Peptides 
**			for the specified Jobs
**
**	Auth:	mem
**	Date:	11/27/2006
**			12/01/2006 mem - Now using udfParseDelimitedIntegerList to parse @JobList
**
*****************************************************/
(
	@JobList varchar(4000),					-- Comma separated list of one or more jobs
	@message varchar(512)='' output
)
As
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	declare @JobCount int
	declare @JobMin int
	declare @JobMax int
	declare @JobDescription varchar(128)

	Set @JobList = IsNull(@JobList, '')
	set @message = ''
	
	---------------------------------------------------
	-- Create two temporary tables
	---------------------------------------------------
	--
	CREATE TABLE #Tmp_JobsToProcess (
		Job int NOT NULL
	)
	
	CREATE TABLE #Tmp_PeptideStateIDs (
		Job int NOT NULL,
		Peptide_ID int NOT NULL,
		State_ID tinyint NOT NULL
	)
	
	---------------------------------------------------
	-- Populate #Tmp_JobsToProcess
	---------------------------------------------------
	--
	INSERT INTO #Tmp_JobsToProcess (Job)
	SELECT Value
	FROM dbo.udfParseDelimitedIntegerList(@JobList, ',')
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	
	Set @JobCount = @myRowCount
	
	If @myError <> 0
	Begin
		set @message = 'Error parsing @JobList: ' + @JobList
		Goto Done
	End
	
	If @myRowCount = 0
	Begin
		set @message = 'Error: @JobList parameter is empty'
		Set @myError = 50000
		Goto Done
	End
	Else
	Begin
		If @JobCount = 1
		Begin
			-- Just one job in @JobList
			SELECT @JobDescription = 'Job ' + Convert(varchar(12), Job)
			FROM #Tmp_JobsToProcess
		End
		Else
		Begin
			-- Multiple jobs in @JobList
			SELECT @JobMin = Min(Job)
			FROM #Tmp_JobsToProcess

			SELECT @JobMax = Max(Job)
			FROM #Tmp_JobsToProcess

			Set @JobDescription = 'Jobs ' + Convert(varchar(12), IsNull(@JobMin, 0)) + ' to ' + Convert(varchar(12), IsNull(@JobMin, 0)) + ' (' + Convert(varchar(12), @JobCount) + ' jobs)'
		End

		Set @JobDescription = IsNull(@JobDescription, 'Job ??')
	End
	
	---------------------------------------------------
	-- Populate a temporary table with the peptides for the job(s)
	---------------------------------------------------
	--
	INSERT INTO #Tmp_PeptideStateIDs (Job, Peptide_ID, State_ID)
	SELECT Analysis_ID, Peptide_ID, 1 AS State_ID
	FROM T_Peptides Pep INNER JOIN
		 #Tmp_JobsToProcess JobQ ON Pep.Analysis_ID = JobQ.Job
	GROUP BY Analysis_ID, Peptide_ID
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error

	If @myRowCount = 0
	Begin
		-- Update @message with a warning, but do not return an error
		set @message = 'Warning: No peptides found for ' + @JobDescription
		Goto Done
	End
	
	---------------------------------------------------
	-- Update the State_ID values to 2 for any peptides that
	--  are only found in reversed or scrambled proteins
	---------------------------------------------------
	UPDATE #Tmp_PeptideStateIDs
	SET State_ID = 2
	FROM #Tmp_PeptideStateIDs INNER JOIN 
		 (	SELECT Job, Peptide_ID
			FROM (	SELECT  Pep.Analysis_ID as Job, Pep.Peptide_ID, COUNT(*) AS Protein_Count, 
							SUM(CASE WHEN Prot.Reference LIKE 'reversed[_]%' OR
										  Prot.Reference LIKE 'scrambled[_]%' OR
										  Prot.Reference LIKE '%[:]reversed' 
								THEN 1 
								ELSE 0 
								END) AS Rev_Protein_Count
					FROM #Tmp_JobsToProcess JobQ INNER JOIN
						 T_Peptides Pep ON JobQ.Job = Pep.Analysis_ID INNER JOIN
						 T_Peptide_to_Protein_Map PPM ON 
						  Pep.Peptide_ID = PPM.Peptide_ID INNER JOIN
						 T_Proteins Prot ON PPM.Ref_ID = Prot.Ref_ID
					GROUP BY Pep.Analysis_ID, Pep.Peptide_ID
				) LookupQ
			WHERE Rev_Protein_Count > 0 AND 
				  Rev_Protein_Count = Protein_Count
		  ) PeptidesToUpdateQ ON #Tmp_PeptideStateIDs.Peptide_ID = PeptidesToUpdateQ.Peptide_ID AND
								 #Tmp_PeptideStateIDs.Job = PeptidesToUpdateQ.Job
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error

	---------------------------------------------------
	-- Apply the changes to T_Peptides
	---------------------------------------------------
	UPDATE T_Peptides
	SET State_ID = #Tmp_PeptideStateIDs.State_ID
	FROM T_Peptides Pep INNER JOIN #Tmp_PeptideStateIDs
		 ON #Tmp_PeptideStateIDs.Job = Pep.Analysis_ID AND
			#Tmp_PeptideStateIDs.Peptide_ID = Pep.Peptide_ID AND
			#Tmp_PeptideStateIDs.State_ID <> Pep.State_ID
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error

	set @message = 'Updated State_ID values for ' + convert(varchar(12), @myRowCount) + ' peptides for ' + @JobDescription

	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:
	return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[UpdatePeptideStateID] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[UpdatePeptideStateID] TO [MTS_DB_Lite] AS [dbo]
GO

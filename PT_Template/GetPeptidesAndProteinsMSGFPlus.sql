/****** Object:  StoredProcedure [dbo].[GetPeptidesAndProteinsMSGFPlus] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure GetPeptidesAndProteinsMSGFPlus
/****************************************************
**
**	Desc: 
**		Returns a list of peptides and proteins identified for the given Set of MSGF+ analysis jobs
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	11/13/2013 mem - Initial version
**			11/14/2013 mem - Now converting the Average FDR to decimal(9, 5)
**    
*****************************************************/
(
	@JobList varchar(max),							-- Comma separated list of MSGF+ job numbers	
	@MSGFPlusFDR real = 0.05,						-- Value between 0 and 1, default is 0.05, which is 5% FDR
	@ShowJobDetails tinyint = 0,					-- When 0, then rolls up the peptides and proteins for all jobs; when 1, then reports peptides/proteins on a job-by-job basis
	@ComputeProteinCoverage tinyint = 1,
	@IncludeDecoyProteins tinyint = 0,				-- Set to 1 to include Decoy Proteins (XXX_)
	@WritePeptidesToTempDB tinyint = 0,				-- When 0, then returns the data as resultsets; when 1 then saves the results in the TempDB on this server
	@TempDBPeptideTable varchar(255) = 'T_Tmp_MSGFPlus_Peptides',		-- Table name for the peptide table to create (or overwrite) in the TempDB if @WritePeptidesToTempDB=1
	@TempDBProteinTable varchar(255) = 'T_Tmp_MSGFPlus_Proteins',		-- Table name for the protein table to create (or overwrite) in the TempDB if @WritePeptidesToTempDB=1
	@message varchar(512) = '' output
)
As
	Set NoCount On
	
	Declare @myRowCount int
	Declare @myError int
	Set @myRowCount = 0
	Set @myError = 0

	Declare @S varchar(2048)
	Declare @TargetPeptideTablePath varchar(512) = ''
	Declare @TargetProteinTablePath varchar(512) = ''

	--------------------------------------------------------------
	-- Validate the inputs
	--------------------------------------------------------------

	Set @JobList = IsNull(@JobList, '')
	
	Set @MSGFPlusFDR = IsNull(@MSGFPlusFDR, 0.05)
	Set @ShowJobDetails = IsNull(@ShowJobDetails, 0)
	Set @ComputeProteinCoverage = IsNull(@ComputeProteinCoverage, 1)
	Set @IncludeDecoyProteins = IsNull(@IncludeDecoyProteins, 0)
	
	Set @WritePeptidesToTempDB = IsNull(@WritePeptidesToTempDB, 0)
	Set @TempDBPeptideTable = IsNull(@TempDBPeptideTable, 'T_Tmp_MSGFPlus_Peptides')
	Set @TempDBProteinTable = IsNull(@TempDBProteinTable, 'T_Tmp_MSGFPlus_Proteins')
	
	Set @message = ''

	--------------------------------------------------------------
	-- Parse the job list
	--------------------------------------------------------------

	CREATE TABLE #Tmp_JobsToProcess (
		Job int
	)

	INSERT INTO #Tmp_JobsToProcess
	SELECT Value
	FROM dbo.udfParseDelimitedIntegerList(@JobList, ',')

	If Not Exists (Select * from #Tmp_JobsToProcess)
	Begin
		Print 'Job list was empty'
		Goto Done
	End

	
	If @WritePeptidesToTempDB > 0
	Begin
				
		Set @TargetPeptideTablePath = 'TempDB..' + '[' + @TempDBPeptideTable + ']'
		Set @TargetProteinTablePath = 'TempDB..' + '[' + @TempDBProteinTable + ']'

		If Exists (Select * from tempdb.sys.tables where Name = @TempDBPeptideTable)
		Begin
			Set @S = 'Drop table ' + @TargetPeptideTablePath
			Exec (@S)
		End

		If Exists (Select * from tempdb.sys.tables where Name = @TempDBProteinTable)
		Begin
			Set @S = 'Drop table ' + @TargetProteinTablePath
			Exec (@S)
		End
		
	End
	
	--------------------------------------------------------------
	-- Find the peptides identified by the jobs
	-- Filter on MSGF+ FDR
	--------------------------------------------------------------
	--
	;
	WITH SourcePeptides ( Job, Peptide_ID, Seq_ID, Clean_Sequence, Mod_Count, Mod_Description, Monoisotopic_Mass, FDR )
	AS
	( SELECT P.Job,
	         P.Peptide_ID,
	         P.Seq_ID,
	         T_Sequence.Clean_Sequence,
	         T_Sequence.Mod_Count,
	         T_Sequence.Mod_Description,
	         T_Sequence.Monoisotopic_Mass,
	         MSGFPlus.FDR
	  FROM T_Peptides P
	       INNER JOIN T_Score_MSGFDB MSGFPlus
	         ON P.Peptide_ID = MSGFPlus.Peptide_ID
	   INNER JOIN T_Sequence
	         ON P.Seq_ID = T_Sequence.Seq_ID
	  WHERE (P.Job IN ( SELECT Job
	                    FROM #Tmp_JobsToProcess )) AND
	        (MSGFPlus.FDR <= @MSGFPlusFDR) 
	)
	SELECT PeptideProteinQ.*,
	       CountQ.Peptide_Spectra_Count
	INTO #Tmp_FilteredPeptides
	FROM ( SELECT CASE When @ShowJobDetails = 0 Then 0 Else Job End AS Job,
	              Seq_ID,
	              COUNT(*) AS Peptide_Spectra_Count
	       FROM SourcePeptides
	       GROUP BY CASE When @ShowJobDetails = 0 Then 0 Else Job End, Seq_ID 
	     ) AS CountQ
	     INNER JOIN ( SELECT CASE When @ShowJobDetails = 0 Then 0 Else Job End AS Job,
	                         Prot.Reference AS Protein_Accession,
	                         Prot.Ref_ID,
	                         S.Seq_ID AS Peptide_Seq_ID,
	                         S.Clean_Sequence AS Peptide,
	                         S.Mod_Count,
	                         S.Mod_Description,
	                         Convert(decimal(9, 5), MIN(S.FDR)) AS Peptide_FDR
	                  FROM SourcePeptides S
	                       INNER JOIN T_Peptide_to_Protein_Map PPM
	                         ON S.Peptide_ID = PPM.Peptide_ID
	                       INNER JOIN T_Proteins Prot
	                         ON PPM.Ref_ID = Prot.Ref_ID
	                  WHERE @IncludeDecoyProteins > 0 Or Prot.Reference Not Like 'XXX[_]%'
	                  GROUP BY CASE When @ShowJobDetails = 0 Then 0 Else Job End, 
	                           Prot.Reference, Prot.Ref_ID, Seq_ID, Clean_Sequence, 
	                           Mod_Count, Mod_Description, S.Monoisotopic_Mass
	          ) PeptideProteinQ
	       ON CountQ.Job = PeptideProteinQ.Job AND
	       CountQ.Seq_ID = PeptideProteinQ.Peptide_Seq_ID;

	--
	SELECT @myRowCount = @@rowcount, @myError = @@error							
	
	--------------------------------------------------------------
	-- Rollup the peptides to proteins
	--------------------------------------------------------------
	--	
	SELECT CASE When @ShowJobDetails = 0 Then 0 Else Job End AS Job,
	       Protein_Accession,
	       Ref_ID,
	       SUM(Peptide_Spectra_Count) AS Protein_Spectra_Count,
	       COUNT(DISTINCT Peptide_Seq_ID) AS Unique_Peptide_Count,
	       CONVERT(decimal(9, 5), AVG(Peptide_FDR)) AS Protein_FDR,
	       CONVERT(decimal(9, 5), NULL) AS Coverage_PMTs
	INTO #Tmp_FilteredProteins
	FROM #Tmp_FilteredPeptides
	GROUP BY CASE When @ShowJobDetails = 0 Then 0 Else Job End, Protein_Accession, Ref_ID
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error							

	--------------------------------------------------------------
	-- Report the filtered peptides
	--------------------------------------------------------------
	--
	Set @S = ''
	Set @S = @S + ' SELECT '
	If @ShowJobDetails > 0
		Set @S = @S +    ' Job,'
	Set @S = @S +        ' Protein_Accession, Peptide,'
	Set @S = @S +        ' Mod_Count, Mod_Description,'
	Set @S = @S +        ' Peptide_FDR, Peptide_Spectra_Count, Peptide_Seq_ID'
	If @WritePeptidesToTempDB > 0
		Set @S = @S + ' INTO ' + @TargetPeptideTablePath
	Set @S = @S + ' FROM #Tmp_FilteredPeptides'
	
	Exec (@S)
	
	--------------------------------------------------------------
	-- Compute coverage if requested
	--------------------------------------------------------------
	--	
	if @ComputeProteinCoverage > 0
		exec ComputeProteinCoverageTempTables
		
	--------------------------------------------------------------
	-- Report the filtered proteins
	--------------------------------------------------------------
	--
	Set @S = ''
	Set @S = @S + ' SELECT '
	If @ShowJobDetails > 0
		Set @S = @S +    ' Job,'
	Set @S = @S +        ' Protein_Accession, Protein_Spectra_Count,'
	Set @S = @S +        ' Unique_Peptide_Count, Protein_FDR'
	If @ComputeProteinCoverage > 0
		Set @S = @S +   ', Coverage_PMTs'
	Set @S = @S +       ', Prot.Description'
	If @WritePeptidesToTempDB > 0
		Set @S = @S + ' INTO ' + @TargetProteinTablePath
	Set @S = @S + ' FROM #Tmp_FilteredProteins FP'
	Set @S = @S +      ' INNER JOIN T_Proteins Prot ON FP.Ref_ID = Prot.Ref_ID'
	
	Exec (@S)

	If @WritePeptidesToTempDB > 0
		Select @TargetPeptideTablePath as TargetPeptideTable, @TargetProteinTablePath as TargeProteinTable
	
Done:
	If @myError <> 0
		SELECT @Message As ErrorMessage
			
	Return @myError

GO

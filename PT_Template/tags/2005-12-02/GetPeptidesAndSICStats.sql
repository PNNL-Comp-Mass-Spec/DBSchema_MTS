SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[GetPeptidesAndSICStats]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[GetPeptidesAndSICStats]
GO


CREATE Procedure dbo.GetPeptidesAndSICStats
/****************************************************
**
**	Desc: 
**		Returns a list of peptides and SIC stats for the
**		given list of jobs
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**		Auth: mem
**		Date: 09/27/2005
**    
*****************************************************/
	@JobList varchar(4000),						-- Comma separated list of job numbers
	@CleavageStateMinimum tinyint = 2,
	@message varchar(512) = '' output
As
	Set NoCount On
	
	Declare @myRowCount int
	Declare @myError int
	Set @myRowCount = 0
	Set @myError = 0

	Set @message = ''

	Declare @S nvarchar(4000)
	Declare @result int

	--------------------------------------------------------------
	-- Retrieve the data for each job, using temporary table #Tmp_PeptidesAndSICStats
	-- as an interim processing table to reduce query complexity and
	-- placing the results in temporary table #Tmp_PeptidesAndSICStats_Results
	--------------------------------------------------------------

/*
	if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[#Tmp_PeptidesAndSICStats_Results]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		drop table [dbo].[#Tmp_PeptidesAndSICStats_Results]
	
	if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[#Tmp_PeptidesAndSICStats]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		drop table [dbo].[#Tmp_PeptidesAndSICStats]
*/

	-- Create the temporary results table
	CREATE TABLE [dbo].[#Tmp_PeptidesAndSICStats_Results] (
		[SIC_Job] [int] NOT NULL ,
		[Job] [int] NOT NULL ,
		[Dataset] [varchar](128) NOT NULL ,
		[Reference] [varchar](255) NOT NULL ,
		[Cleavage_State] [tinyint] NULL,
		[Seq_ID] [int] NOT NULL ,
		[Peptide] [varchar](850) ,
		[XCorr_Avg] [real] NULL ,
		[Discriminant_Avg] [real] NULL ,
		[Optimal_Scan_Number_Avg] [real] NULL ,
		[Time_Avg] [real] NULL,
		[Intensity_Max] [float] NULL,
		[Area_Max] [float] NULL,
		[SN_Max] [real] NULL,
		[FWHM_Max] [int] NULL
	) ON [PRIMARY]
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error

	-- Create the interim processing table
	CREATE TABLE [dbo].[#Tmp_PeptidesAndSICStats] (
		[SIC_Job] [int] NOT NULL ,
		[Job] [int] NOT NULL ,
		[Dataset_ID] [int] NOT NULL ,
		[Dataset] [varchar](128) NOT NULL ,
		[Reference] [varchar](255) NOT NULL ,
		[Seq_ID] [int] NOT NULL ,
		[Peptide] [varchar](850) ,
		[DiscriminantScoreNorm] [real] NULL ,
		[XCorr] [real] NULL ,
		[DeltaCn2] [real] NULL ,
		[Charge_State] [smallint] NOT NULL ,
		[Scan_Number] [int] NOT NULL,
		[Cleavage_State] [tinyint] NULL,
		[Optimal_Peak_Apex_Scan_Number] [int] NULL,
		[Peak_Intensity] [float] NULL,
		[Peak_Area] [float] NULL,
		[Peak_SN_Ratio] [real] NULL,
		[FWHM_In_Scans] [int] NULL
		--	[Scan_Time] [real] NULL,
	) ON [PRIMARY]
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error


/*
	-- Add a clustered index on Seq_ID
	CREATE CLUSTERED INDEX [IX_Tmp_PeptidesAndSICStats] ON [dbo].[#Tmp_PeptidesAndSICStats]([Seq_ID]) ON [PRIMARY]
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error

	-- Add the primary key (spans 5 columns)

	ALTER TABLE [dbo].[#Tmp_PeptidesAndSICStats]
	ADD CONSTRAINT [PK_Tmp_PeptidesAndSICStats] PRIMARY KEY  NONCLUSTERED (
		Job, Seq_ID, Scan_Number, Charge_State, Reference) ON [PRIMARY]
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
*/


	-- Add an index on Scan_Number and SIC_Job
	CREATE INDEX #IX_Tmp_PeptidesAndSICStats_ScanNumberSICJob ON [dbo].[#Tmp_PeptidesAndSICStats] (Scan_Number, SIC_Job) ON [PRIMARY]
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error


	-- Parse out each of the jobs in @JobList
	-- Obtain the data and place in #Tmp_PeptidesAndSICStats_Results

	-- Make sure @JobList ends in a comma
	Set @JobList = LTrim(RTrim(@JobList)) + ','
	
	Declare @ProcessedJobs varchar(5000)
	Declare @CurrentJob varchar(1024)
	Declare @CommaLoc int
	
	Set @ProcessedJobs = ','
	Set @CommaLoc = CharIndex(',', @JobList)
	While @CommaLoc >= 1
	Begin
		Set @CurrentJob = LTrim(Left(@JobList, @CommaLoc-1))
		Set @JobList = SubString(@JobList, @CommaLoc+1, Len(@JobList))
	
		If CharIndex(',' + @CurrentJob + ',', @ProcessedJobs) < 1 And IsNumeric(@CurrentJob) = 1
		Begin
			-- Jobs has not yet been processed
			-- Add to @ProcessedJobs then process
			Set @ProcessedJobs = @ProcessedJobs + @CurrentJob + ','
			
			TRUNCATE TABLE #Tmp_PeptidesAndSICStats

			-- Populate the interim processing table with the data for @CurrentJob
			INSERT INTO #Tmp_PeptidesAndSICStats (
				SIC_Job, Job, Dataset_ID, Dataset, Reference, Seq_ID, Peptide,
				DiscriminantScoreNorm, XCorr, DeltaCn2, Charge_State, Scan_Number, Cleavage_State)
			SELECT DISTINCT DS.SIC_Job, AD.Job, DS.Dataset_ID, AD.Dataset, Pro.Reference,
				Pep.Seq_ID, Pep.Peptide, SD.DiscriminantScoreNorm, SS.XCorr, SS.DeltaCn2,
				Pep.Charge_State, Pep.Scan_Number, PPM.Cleavage_State
			FROM T_Analysis_Description AD INNER JOIN
				T_Datasets DS ON AD.Dataset_ID = DS.Dataset_ID INNER JOIN
				T_Peptides Pep ON AD.Job = Pep.Analysis_ID INNER JOIN
				T_Score_Sequest SS ON Pep.Peptide_ID = SS.Peptide_ID INNER JOIN
				T_Peptide_to_Protein_Map PPM ON Pep.Peptide_ID = PPM.Peptide_ID INNER JOIN
				T_Proteins Pro ON PPM.Ref_ID = Pro.Ref_ID INNER JOIN
				T_Score_Discriminant SD ON Pep.Peptide_ID = SD.Peptide_ID
			WHERE AD.Process_State = 70 AND
				PPM.Cleavage_State >= @CleavageStateMinimum AND
				AD.job = @CurrentJob AND (
				Pep.Charge_State = 1 AND SS.DeltaCn2 >= 0.1 AND SS.XCorr >= 1.9 OR
				Pep.Charge_State = 2 AND SS.DeltaCn2 >= 0.1 AND SS.XCorr >= 2.2 OR
				Pep.Charge_State = 3 AND SS.DeltaCn2 >= 0.1 AND SS.XCorr >= 3.75
				)
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error

			-- Update the interim processing table to include the DS_SIC data	
			UPDATE #Tmp_PeptidesAndSICStats
			SET Optimal_Peak_Apex_Scan_Number = DS_SIC.Optimal_Peak_Apex_Scan_Number, 
				Peak_Intensity = DS_SIC.Peak_Intensity, 
				Peak_Area = DS_SIC.Peak_Area, 
				Peak_SN_Ratio = DS_SIC.Peak_SN_Ratio, 
				FWHM_In_Scans = DS_SIC.FWHM_In_Scans
			FROM #Tmp_PeptidesAndSICStats S INNER JOIN
				T_Dataset_Stats_SIC DS_SIC ON 
				DS_SIC.Frag_Scan_Number = S.Scan_Number AND 
				DS_SIC.Job = S.SIC_Job
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error

          
			-- Append the new results to #Tmp_PeptidesAndSICStats_Results
			INSERT INTO #Tmp_PeptidesAndSICStats_Results (
				SIC_Job, Job, Dataset, Reference, 
				Cleavage_State, Seq_ID, Peptide, 
				XCorr_Avg, 
				Discriminant_Avg,
				Optimal_Scan_Number_Avg, 
				Time_Avg, 
				Intensity_Max, 
				Area_Max, 
				SN_Max, 
				FWHM_Max)
			SELECT S.SIC_Job, S.Job, S.Dataset, S.Reference, 
				MAX(S.Cleavage_State) AS Cleavage_State, S.Seq_ID, S.Peptide, 
				AVG(S.XCorr) AS XCorr_Avg, 
				AVG(S.DiscriminantScoreNorm) AS Discriminant_Avg, 
				AVG(S.Optimal_Peak_Apex_Scan_Number) AS Optimal_Scan_Number_Avg, 
				AVG(DS_Scans.Scan_Time) AS Time_Avg, 
				MAX(S.Peak_Intensity) AS Intensity_Max, 
				MAX(S.Peak_Area) AS Area_Max, 
				MAX(S.Peak_SN_Ratio) AS SN_Max, 
				MAX(S.FWHM_In_Scans) AS FWHM_Max
			FROM #Tmp_PeptidesAndSICStats S INNER JOIN
				T_Dataset_Stats_Scans DS_Scans ON 
				S.SIC_Job = DS_Scans.Job AND 
				S.Optimal_Peak_Apex_Scan_Number = DS_Scans.Scan_Number
			GROUP BY S.SIC_Job, S.Job, S.Dataset, S.Reference, S.Seq_ID, S.Peptide
    		ORDER BY S.Dataset, S.Job, AVG(S.XCorr) DESC, S.Seq_ID
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error

		End
		
		Set @CommaLoc = CharIndex(',', @JobList)
	End	
	

	-- Query #Tmp_PeptidesAndSICStats_Results to obtain the data
	SELECT *
	FROM #Tmp_PeptidesAndSICStats_Results
	ORDER BY Dataset, Job, XCorr_Avg DESC, Seq_ID

Done:
	
	return @myError


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


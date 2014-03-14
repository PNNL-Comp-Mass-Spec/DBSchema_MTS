/****** Object:  StoredProcedure [dbo].[DuplicateNETValues] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.DuplicateNETValues
/****************************************************
**
**	Desc: 
**		Duplicates the NET values from the source job to the target job
**		Only appropriate if both jobs have very similar gradients and very similar observed elution times for the same peptides
**
**		This process will be most accurate for LC-MS/MS datasets analyzed with two different tools (e.g. both MSGF+ and MSAlign)
**		By default, @RequireMatchingDataset=1 meaning the two jobs must come from the same dataset
**
**	Return values: 0 if no error; otherwise error code
**
**	Auth:	mem
**	Date:	02/25/2014
**    
*****************************************************/
(
	@SourceJob int,
	@TargetJob int,
	@RequireMatchingDataset tinyint = 1,
	@MaxElutionDifferenceMinutes real = 10,
	@InfoOnly tinyint = 1,
	@ShowResultsAfterUpdate tinyint = 1,
	@message varchar(255) = '' OUTPUT
)
AS

	set nocount on

	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	---------------------------------------------------
	-- Validate the inputs
	---------------------------------------------------

	If IsNull(@SourceJob, 0) = 0
	Begin
		Set @Message = 'Source job not defined'
		Set @myerror = 50000
		Goto Done
	End

	If IsNull(@TargetJob, 0) = 0
	Begin
		Set @Message = 'Target job not defined'
		Set @myerror = 50001
		Goto Done
	End
	
	Set @RequireMatchingDataset = IsNull(@RequireMatchingDataset, 1)
	Set @MaxElutionDifferenceMinutes = IsNull(@MaxElutionDifferenceMinutes, 10)
	Set @InfoOnly = IsNull(@InfoOnly, 1)
	Set @ShowResultsAfterUpdate = IsNull(@ShowResultsAfterUpdate, 1)	
	Set @message = ''
	
	---------------------------------------------------
	-- Validate the inputs
	---------------------------------------------------

	Declare @Dataset1 int = 0
	Declare @Dataset2 int = 0
	
	SELECT @Dataset1 = Dataset_ID
	FROM T_Analysis_Description
	WHERE Job = @SourceJob
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	If @myRowCount = 0
	Begin
		Set @message = 'Source job not found in T_Analysis_Description: ' + Convert(varchar(12), @SourceJob)
		Set @myerror = 50002
		Goto Done
	End
	
	SELECT @Dataset2 = Dataset_ID
	FROM T_Analysis_Description
	WHERE Job = @TargetJob
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	If @myRowCount = 0
	Begin
		Set @message = 'Target job not found in T_Analysis_Description: ' + Convert(varchar(12), @TargetJob)
		Set @myerror = 50003
		Goto Done
	End
	
	
	If @RequireMatchingDataset > 0 And @Dataset1 <> @Dataset2
	Begin
		Set @message = 'Source and Target jobs do not have the same dataset'
		Set @myerror = 50004
		Goto Done
	End

	---------------------------------------------------
	-- Copy NET values from the Source Job to the Target Job
	---------------------------------------------------

	Create Table #Tmp_NET_Obs_Updates
	(
		Peptide_ID int,
		GANET_Obs_Old real null,
		GANET_Obs_New real null
	)

	Insert Into #Tmp_NET_Obs_Updates
	SELECT Peptide_ID,
	       GANET_Obs_Old,
	       GANET_Obs_New
	FROM ( SELECT *,
	              Row_Number() OVER ( Partition By Peptide_ID Order By timediff ) AS DiffRank
	       FROM ( SELECT TargetQ.Peptide_ID,
	                     TargetQ.Scan_Time_Peak_Apex,
	                     ABS(SourceQ.Scan_Time_Peak_Apex - TargetQ.Scan_Time_Peak_Apex) AS TimeDiff,
	                     TargetQ.GANET_Obs AS GANET_Obs_Old,
	                     SourceQ.GANET_Obs AS GANET_Obs_New
	              FROM ( SELECT Peptide_ID,
	                            Scan_Time_Peak_Apex,
	                            GANET_Obs
	                     FROM T_Peptides
	                     WHERE Job = @TargetJob
	                   ) TargetQ
	                   CROSS JOIN ( SELECT Peptide_ID,
	                                       Scan_Time_Peak_Apex,
	                                       Ganet_Obs
	      FROM T_Peptides
	                        WHERE Job = @SourceJob 
	                              ) SourceQ
	              WHERE ABS(SourceQ.Scan_Time_Peak_Apex - TargetQ.Scan_Time_Peak_Apex) < @MaxElutionDifferenceMinutes 
	            ) LinkQ 
	      ) SortQ
	WHERE DiffRank = 1
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	
	If @InfoOnly > 0
	Begin
		SELECT *
		FROM #Tmp_NET_Obs_Updates
		ORDER BY GANET_Obs_Old
	End
	Else
	Begin
		UPDATE T_Peptides
		SET GANET_Obs = NULL
		WHERE Job = @TargetJob
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		UPDATE T_Peptides
		SET GANET_Obs = UpdateQ.GANET_Obs_New
		FROM T_Peptides P
		     INNER JOIN #Tmp_NET_Obs_Updates UpdateQ
		       ON P.Peptide_ID = UpdateQ.Peptide_ID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		Set @message = 'Updated NET values for ' + Convert(varchar(12), @myRowCount) + ' peptides in T_Peptides for job ' + Convert(varchar(12), @TargetJob) + ' using job ' + Convert(varchar(12), @SourceJob)
		
		UPDATE T_Analysis_Description
		SET GANET_Fit = SourceQ.GANET_Fit,
		    GANET_Slope = SourceQ.GANET_Slope,
		    GANET_Intercept = SourceQ.GANET_Intercept,
		    GANET_RSquared = SourceQ.GANET_RSquared,
		    ScanTime_NET_Slope = SourceQ.ScanTime_NET_Slope,
		    ScanTime_NET_Intercept = SourceQ.ScanTime_NET_Intercept,
		    ScanTime_NET_RSquared = SourceQ.ScanTime_NET_RSquared,
		    ScanTime_NET_Fit = SourceQ.ScanTime_NET_Fit,
		    Regression_Order = SourceQ.Regression_Order,
		    Regression_Filtered_Data_Count = SourceQ.Regression_Filtered_Data_Count,
		    Regression_Equation = SourceQ.Regression_Equation,
		    Regression_Equation_XML = SourceQ.Regression_Equation_XML
		FROM T_Analysis_Description Target
		     CROSS JOIN ( SELECT GANET_Fit,
		                         GANET_Slope,
		                         GANET_Intercept,
		                         GANET_RSquared,
		                         ScanTime_NET_Slope,
		                         ScanTime_NET_Intercept,
		                         ScanTime_NET_RSquared,
		                         ScanTime_NET_Fit,
		                         Regression_Order,
		                         Regression_Filtered_Data_Count,
		                         Regression_Equation,
		                         Regression_Equation_XML
		                  FROM T_Analysis_Description
		                  WHERE Job = @SourceJob
		                  ) SourceQ
		WHERE Target.Job = @TargetJob
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		Exec PostLogEntry 'Normal', @message, 'DuplicateNETValues'
		
		If @ShowResultsAfterUpdate <> 0
		Begin
			SELECT *
			FROM T_Peptides
			WHERE Job = @TargetJob
			ORDER BY Scan_Time_Peak_Apex
		End
		
	End

	Drop table #Tmp_NET_Obs_Updates

Done:

	If @myError <> 0
	Begin
		If @InfoOnly = 1
			Print @message
		Else
			Exec PostLogEntry 'Error', @message, 'DuplicateNETValues'
	End
	
	Return @myError


GO

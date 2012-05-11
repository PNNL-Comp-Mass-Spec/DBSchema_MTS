/****** Object:  StoredProcedure [dbo].[ComputePeptideGANET] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCedure ComputePeptideGANET
/********************************************************
**	Populates the GANET_Obs field in T_Peptides
**	If the Job's fit value is less than @MinNETFit, then no
**	observed NET value is computed (return code is 0, though)
**
**	Returns a status message in @message
**
**	Date:	07/05/2004 mem
**			09/14/2004 mem - Removed conglomerate GANET_Avg computations
**			01/22/2005 mem - Added @MinNETRSquared column and switched to using the ScanTime_NET columns
**			01/06/2012 mem - Updated to use T_Peptides.Job
**
*********************************************************/
(
	@Job int,
	@MinNETFit real = 0.8,
	@MinNETRSquared real = 0.1,
	@message varchar(255) = '' output
)
AS

	Set NoCount On

	Declare @myError int,
			@myRowCount int,
			@JobNETFit real,
			@JobNETRSquared real
			
	Set @myError = 0
	Set @message = ''
	Set @JobNETFit = 0
	Set @JobNETRSquared = 0
	
	Declare @JobStr varchar(12)
	Set @JobStr = Convert(varchar(12), @Job)

	-- Clear the existing GANET values for this job in T_Peptides
	UPDATE T_Peptides
	SET GANET_Obs = NULL
	WHERE Job = @Job AND NOT GANET_Obs Is NULL
	--
	SELECT @myError = @@error, @myRowCount = @@RowCount
	--
	If (@myError <> 0) 
	Begin
		Set @message = 'Error setting existing Ganet values to NULL in T_Peptides for job ' + @JobStr
		Set @myError = 101
		Goto Done
	End

	-- See if this job's fit is above @MinNETFit and its RSquared is above @MinNETRSquared
	SELECT @JobNETFit = IsNull(ScanTime_NET_Fit, 0), @JobNETRSquared = IsNull(ScanTime_NET_RSquared, 0)
	FROM T_Analysis_Description
	WHERE Job = @Job
	--
	If (@JobNETFit < @MinNETFit AND @JobNETRSquared < @MinNETRSquared) OR @JobNETRSquared < @MinNETRSquared	
	Begin
		-- Note, we do not set an error code here, since we want the job to continue processing, 
		-- even if the observed NET values cannot be computed
		Set @message = ''
		if @JobNETFit < @MinNETFit
			Set @message = 'the NET Fit value of ' + convert(varchar(9), Round(@JobNETFit, 3)) + ' is less than required minimum of ' + Convert(Varchar(9), Round(@MinNETFit, 3))
		
		if @JobNETRSquared < @MinNETRSquared
		Begin
			if Len(@message) > 0
				Set @Message = @message + ' and '
			Set @message = @message + 'the NET RSquared value of ' + convert(varchar(9), Round(@JobNETRSquared, 3)) + ' is less than required minimum of ' + Convert(Varchar(9), Round(@MinNETRSquared, 3))
		End
		
		Set @message = 'Warning: In job ' + @JobStr + ' ' + @message
		Goto Done
	End


	Declare @UsePeakApex tinyint
	Set @UsePeakApex = 1
	
	-- Calculate the observed GANET values for the peptides for this job
	If @UsePeakApex <> 0
		UPDATE T_Peptides
		SET GANET_Obs = DSS_PeakApex.Scan_Time * TAD.ScanTime_NET_Slope + TAD.ScanTime_NET_Intercept
		FROM T_Peptides INNER JOIN
			T_Analysis_Description TAD ON 
			T_Peptides.Job = TAD.Job INNER JOIN
			V_SIC_Job_to_PeptideHit_Map JobMap ON 
			TAD.Job = JobMap.Job INNER JOIN
			T_Dataset_Stats_Scans DSS_PeakApex ON 
			JobMap.SIC_Job = DSS_PeakApex.Job INNER JOIN
			T_Dataset_Stats_SIC DSSIC ON 
			JobMap.SIC_Job = DSSIC.Job AND 
			T_Peptides.Scan_Number = DSSIC.Frag_Scan_Number AND 
			DSS_PeakApex.Scan_Number = DSSIC.Optimal_Peak_Apex_Scan_Number
		WHERE T_Peptides.Job = @Job
	Else	
		UPDATE T_Peptides
		SET GANET_Obs = DSS.Scan_Time * TAD.ScanTime_NET_Slope + TAD.ScanTime_NET_Intercept
		FROM T_Peptides INNER JOIN
			T_Analysis_Description TAD ON 
			T_Peptides.Job = TAD.Job INNER JOIN
			V_SIC_Job_to_PeptideHit_Map JobMap ON 
			TAD.Job = JobMap.Job INNER JOIN
			T_Dataset_Stats_Scans DSS ON 
			JobMap.SIC_Job = DSS.Job
			AND 
			T_Peptides.Scan_Number = DSS.Scan_Number
		WHERE T_Peptides.Job = @Job
	--
	SELECT @myError = @@error, @myRowCount = @@RowCount
	--
	If (@myError <> 0) 
	Begin
		Set @message = 'Error computing new GANET_Obs values in T_Peptides for job ' + @JobStr
		Set @myError = 103
		Goto Done
	End

	If (@myRowCount = 0)
	Begin
		Set @message = 'No records were found in T_Peptides for job ' + @JobStr
		Set @myError = 104
	End
	Else
	Begin
		Set @message = 'Computed observed NET values for job ' + @JobStr + '; ' + convert(varchar(11), @myRowCount) + ' peptides updated'
		Set @myError = 0
	End
	
Done:
	Select @message

	Return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[ComputePeptideGANET] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[ComputePeptideGANET] TO [MTS_DB_Lite] AS [dbo]
GO

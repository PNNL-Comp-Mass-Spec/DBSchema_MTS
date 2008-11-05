/****** Object:  StoredProcedure [dbo].[ComputePeptideNETBulk] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.ComputePeptideNETBulk
/********************************************************
**	Populates the GANET_Obs field in T_Peptides for all jobs
**  associated with the given NET Update Task
**
**	If a given job's fit value is less than @MinNETRSquared, then no
**	observed NET values are computed (return code is 0, though)
**
**	Returns a status message in @message
**
**	Date:	07/05/2004 mem
**			09/14/2004 mem - Removed conglomerate GANET_Avg computations
**			01/22/2005 mem - Added @MinNETRSquared column and switched to using the ScanTime_NET columns
**			05/29/2005 mem - Switched to using T_NET_Update_Task and T_NET_Update_Task_Job_Map; removed parameter @MinNETFit
**			08/16/2005 mem - Switched from using V_SIC_Job_to_PeptideHit_Map to using T_Datasets directly when populating the GANET_Obs values
**						   - Added the option to compute the GANET_Obs values for each job separately in the NET Update Task; 
**							 this shouldn't be necessary, since the whole point of bulk updating is to just run one update query, 
**							 but in certain Peptide DBs, a massive number of Lock Requests have been observed when trying to update
**							 a group of Jobs
**
*********************************************************/
(
	@TaskID int,
	@MinNETRSquared real = 0.1,
	@message varchar(255) = '' output
)
AS

	Set NoCount On

	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0
			
	Set @myError = 0
	Set @message = ''
	
	Declare @TaskIDStr varchar(12)
	Set @TaskIDStr = Convert(varchar(12), @TaskID)

	Declare @InvalidJobCount int
	Declare @ValidJobCount int
	Declare @PeptideUpdateCount int
	
	Set @InvalidJobCount = 0
	Set @ValidJobCount = 0
	Set @PeptideUpdateCount = 0
	
	---------------------------------------------------
	-- Clear the existing NET values for this task's jobs in T_Peptides
	---------------------------------------------------
	--
	UPDATE T_Peptides
	SET GANET_Obs = NULL
	FROM T_Peptides INNER JOIN 
		 T_NET_Update_Task_Job_Map TJM ON T_Peptides.Analysis_ID = TJM.Job
	WHERE TJM.Task_ID = @TaskID AND NOT T_Peptides.GANET_Obs Is NULL
	--
	SELECT @myError = @@error, @myRowCount = @@RowCount
	--
	If (@myError <> 0) 
	Begin
		Set @message = 'Error setting existing NET values to NULL in T_Peptides for Task_ID ' + @TaskIDStr
		Set @myError = 101
		Goto Done
	End

	---------------------------------------------------
	-- Determine the number of jobs with ScanTime_NET_RSquared values below @MinNETRSquared
	---------------------------------------------------
	--	
	SELECT @InvalidJobCount = Count(TAD.Job)
	FROM T_Analysis_Description TAD INNER JOIN 
		 T_NET_Update_Task_Job_Map TJM ON TAD.Job = TJM.Job
	WHERE TJM.Task_ID = @TaskID AND IsNull(TAD.ScanTime_NET_RSquared, 0) < @MinNETRSquared
	--
	SELECT @myError = @@error, @myRowCount = @@RowCount
	
	If @InvalidJobCount > 0	
	Begin
		-- Note, we do not set an error code here, since we want the jobs to continue processing, 
		-- even if the observed NET values cannot be computed
		Set @message = 'Warning: Task_ID ' + @TaskIDStr + ' has ' + Convert(varchar(9), @InvalidJobCount) + ' jobs with NET RSquared values less than required minimum of ' + Convert(Varchar(9), Round(@MinNETRSquared, 3)) + '; the peptides in these jobs will not contain observed NET values'

		Exec PostLogEntry 'Warning', @message, 'ComputePeptideNETBulk'
		Set @message = ''
	End

	---------------------------------------------------
	-- Count the number of valid jobs present
	---------------------------------------------------
	--
	SELECT @ValidJobCount = Count(TAD.Job)
	FROM T_Analysis_Description TAD INNER JOIN 
		 T_NET_Update_Task_Job_Map TJM ON TAD.Job = TJM.Job
	WHERE TJM.Task_ID = @TaskID

	Set @ValidJobCount = @ValidJobCount - IsNull(@InvalidJobCount, 0)
	
	If @ValidJobCount > 0
	Begin
	
		---------------------------------------------------
		-- Calculate the observed NET values for the peptides in this task's jobs
		---------------------------------------------------

		Declare @UsePeakApex tinyint
		Declare @BulkComputeGANETObs tinyint
		
		-- The following two settings are hard-coded
		Set @UsePeakApex = 1
		Set @BulkComputeGANETObs = 0


		If @UsePeakApex <> 0
		Begin
			If @BulkComputeGANETObs = 1
			Begin
				---------------------------------------------------
				-- This method can be used to update all of the jobs in bulk; it should work fine but sometimes fails in certain peptide DBs
				---------------------------------------------------
				UPDATE T_Peptides
				SET GANET_Obs = DSS_PeakApex.Scan_Time * TAD.ScanTime_NET_Slope + TAD.ScanTime_NET_Intercept
				FROM T_Analysis_Description TAD INNER JOIN
					T_NET_Update_Task_Job_Map TJM ON TAD.Job = TJM.Job INNER JOIN
					T_Peptides Pep ON Pep.Analysis_ID = TAD.Job INNER JOIN
					T_Dataset_Stats_SIC DSSIC ON Pep.Scan_Number = DSSIC.Frag_Scan_Number INNER JOIN
					T_Dataset_Stats_Scans DSS_PeakApex ON 
					DSSIC.Optimal_Peak_Apex_Scan_Number = DSS_PeakApex.Scan_Number AND 
					DSSIC.Job = DSS_PeakApex.Job INNER JOIN
					T_Datasets DS ON TAD.Dataset_ID = DS.Dataset_ID AND DSSIC.Job = DS.SIC_Job
				WHERE TJM.Task_ID = @TaskID AND IsNull(TAD.ScanTime_NET_RSquared, 0) >= @MinNETRSquared
				--
				SELECT @myError = @@error, @myRowCount = @@RowCount
				--
				Set @PeptideUpdateCount = @myRowCount
			End		
			Else
			Begin
				---------------------------------------------------
				-- Loop through the jobs defined for @TaskID
				---------------------------------------------------
				
				Declare @Continue int
				Declare @Job int

				Set @Continue = 1
				Set @Job = -1
					
				While @Continue = 1 And @myError = 0
				Begin
					SELECT TOP 1 @Job = Job
					FROM T_NET_Update_Task_Job_Map
					WHERE Task_ID = @TaskID AND Job > @Job
					ORDER BY Job
					--
					SELECT @myError = @@error, @myRowCount = @@RowCount

					If @myRowCount = 0
						Set @Continue = 0
					Else
					Begin

						UPDATE T_Peptides
						SET GANET_Obs = DSS_PeakApex.Scan_Time * TAD.ScanTime_NET_Slope + TAD.ScanTime_NET_Intercept
						FROM T_Analysis_Description TAD INNER JOIN
							T_NET_Update_Task_Job_Map TJM ON TAD.Job = TJM.Job INNER JOIN
							T_Peptides Pep ON Pep.Analysis_ID = TAD.Job INNER JOIN
							T_Dataset_Stats_SIC DSSIC ON Pep.Scan_Number = DSSIC.Frag_Scan_Number INNER JOIN
							T_Dataset_Stats_Scans DSS_PeakApex ON 
							DSSIC.Optimal_Peak_Apex_Scan_Number = DSS_PeakApex.Scan_Number AND 
							DSSIC.Job = DSS_PeakApex.Job INNER JOIN
							T_Datasets DS ON TAD.Dataset_ID = DS.Dataset_ID AND DSSIC.Job = DS.SIC_Job
						WHERE TJM.Task_ID = @TaskID AND TAD.Job = @Job AND IsNull(TAD.ScanTime_NET_RSquared, 0) >= @MinNETRSquared
						--
						SELECT @myError = @@error, @myRowCount = @@RowCount
						--
						Set @PeptideUpdateCount = @PeptideUpdateCount + @myRowCount
									
					End
				End
				
			End
		
		End
		Else
		Begin
			UPDATE T_Peptides
			SET GANET_Obs = DSS.Scan_Time * TAD.ScanTime_NET_Slope + TAD.ScanTime_NET_Intercept
			FROM T_Analysis_Description TAD INNER JOIN
				 T_NET_Update_Task_Job_Map TJM ON TAD.Job = TJM.Job INNER JOIN
				 T_Peptides Pep ON Pep.Analysis_ID = TAD.Job INNER JOIN
				 T_Dataset_Stats_Scans DSS ON Pep.Scan_Number = DSS.Scan_Number INNER JOIN
				 T_Datasets DS ON TAD.Dataset_ID = DS.Dataset_ID AND DSS.Job = DS.SIC_Job			
			WHERE TJM.Task_ID = @TaskID AND IsNull(TAD.ScanTime_NET_RSquared, 0) >= @MinNETRSquared
			--
			SELECT @myError = @@error, @myRowCount = @@RowCount
			--
			Set @PeptideUpdateCount = @myRowCount
		End

		If (@myError <> 0) 
		Begin
			Set @message = 'Error computing new GANET_Obs values in T_Peptides for Task_ID ' + @TaskIDStr
			Set @myError = 103
		End
		Else
		Begin
			If (@PeptideUpdateCount = 0)
			Begin
				Set @message = 'No records were found in T_Peptides for the jobs associated with Task_ID ' + @TaskIDStr
				Set @myError = 104
			End
			Else
			Begin
				Set @message = 'Computed observed NET values for Task_ID ' + @TaskIDStr + '; ' + convert(varchar(11), @PeptideUpdateCount) + ' peptides updated in ' + convert(varchar(9), @ValidJobCount) + ' analysis jobs'
				Set @myError = 0
			End
		End
	
		If @myError = 0
			Exec PostLogEntry 'Normal', @message, 'ComputePeptideNETBulk'
		Else
			Exec PostLogEntry 'Error', @message, 'ComputePeptideNETBulk'
	End
	
Done:

	Return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[ComputePeptideNETBulk] TO [MTS_DB_Dev]
GO
GRANT VIEW DEFINITION ON [dbo].[ComputePeptideNETBulk] TO [MTS_DB_Lite]
GO

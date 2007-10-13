/****** Object:  StoredProcedure [dbo].[UpdateMassTagPeptideProphetStats] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.UpdateMassTagPeptideProphetStats
/****************************************************
**
**	Desc:	Populates T_Mass_Tag_Peptide_Prophet_Stats
**
**	Return values: 0 if no error; otherwise error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	09/14/2006 mem
**			11/15/2006 mem - Replaced use of Truncate Table with Delete From
**			05/21/2007 mem - Replaced PepProphet_Probability_Avg_CS1 with PepProphet_FScore_Avg_CS1
**			09/07/2007 mem - Now posting log entries if the stored procedure runs for more than 2 minutes
**    
*****************************************************/
(
	@RowCountUpdated int = 0 output,
	@message varchar(255) = '' output
)
AS
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	declare @lastProgressUpdate datetime
	Set @lastProgressUpdate = GetDate()

	declare @ProgressUpdateIntervalThresholdSeconds int
	Set @ProgressUpdateIntervalThresholdSeconds = 120
	
	---------------------------------------------------
	-- Clear the outputs
	---------------------------------------------------
	set @RowCountUpdated = 0
	set @message = ''
	
	---------------------------------------------------
	-- Clear T_Mass_Tag_Peptide_Prophet_Stats,
	-- resetting the values to defaults (0 for observation
	-- counts and -100 for stats)
	---------------------------------------------------
	--
	DELETE FROM T_Mass_Tag_Peptide_Prophet_Stats
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error

	---------------------------------------------------
	-- Populate the table using T_Mass_Tags
	---------------------------------------------------
	--	
	INSERT INTO T_Mass_Tag_Peptide_Prophet_Stats (Mass_Tag_ID)
	SELECT Mass_Tag_ID
	FROM T_Mass_Tags
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error

	Set @RowCountUpdated = @myRowCount

	---------------------------------------------------
	-- Update stats for 1+ data
	---------------------------------------------------
	--
	UPDATE T_Mass_Tag_Peptide_Prophet_Stats
	SET ObsCount_CS1 = StatsQ.ObsCount,
		PepProphet_FScore_Max_CS1 = StatsQ.Peptide_Prophet_FScore_Maximum,
		PepProphet_Probability_Max_CS1 = StatsQ.Peptide_Prophet_Probability_Maximum,
		PepProphet_FScore_Avg_CS1 = StatsQ.Peptide_Prophet_FScore_Average
	FROM T_Mass_Tag_Peptide_Prophet_Stats PPS INNER JOIN
		(	SELECT  P.Mass_Tag_ID,
					COUNT(*) AS ObsCount,
					MAX(SD.Peptide_Prophet_FScore) AS Peptide_Prophet_FScore_Maximum, 
    				MAX(SD.Peptide_Prophet_Probability) AS Peptide_Prophet_Probability_Maximum,
    				AVG(SD.Peptide_Prophet_FScore) AS Peptide_Prophet_FScore_Average
			FROM T_Peptides P INNER JOIN
				 T_Score_Discriminant SD ON P.Peptide_ID = SD.Peptide_ID
			WHERE P.Charge_State = 1
			GROUP BY P.Mass_Tag_ID
		) StatsQ ON PPS.Mass_Tag_ID = StatsQ.Mass_Tag_ID
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error

	if DateDiff(second, @lastProgressUpdate, GetDate()) >= @ProgressUpdateIntervalThresholdSeconds
	Begin
		set @message = '...Processing: Populated ObsCount_CS1 in T_Mass_Tag_Peptide_Prophet_Stats (' + Convert(varchar(19), @myRowCount) + ' / ' + Convert(varchar(19), @RowCountUpdated) + ' PMT tags updated)'
		execute PostLogEntry 'Progress', @message, 'UpdateMassTagPeptideProphetStats'
		set @message = ''
		set @lastProgressUpdate = GetDate()
	End

	---------------------------------------------------
	-- Update stats for 2+ data
	---------------------------------------------------
	--
	UPDATE T_Mass_Tag_Peptide_Prophet_Stats
	SET ObsCount_CS2 = StatsQ.ObsCount,
		PepProphet_FScore_Max_CS2 = StatsQ.Peptide_Prophet_FScore_Maximum,
		PepProphet_Probability_Max_CS2 = StatsQ.Peptide_Prophet_Probability_Maximum,
		PepProphet_FScore_Avg_CS2 = StatsQ.Peptide_Prophet_FScore_Average
	FROM T_Mass_Tag_Peptide_Prophet_Stats PPS INNER JOIN
		(	SELECT  P.Mass_Tag_ID,
					COUNT(*) AS ObsCount,
					MAX(SD.Peptide_Prophet_FScore) AS Peptide_Prophet_FScore_Maximum, 
    				MAX(SD.Peptide_Prophet_Probability) AS Peptide_Prophet_Probability_Maximum,
    				AVG(SD.Peptide_Prophet_FScore) AS Peptide_Prophet_FScore_Average
			FROM T_Peptides P INNER JOIN
				 T_Score_Discriminant SD ON P.Peptide_ID = SD.Peptide_ID
			WHERE P.Charge_State = 2
			GROUP BY P.Mass_Tag_ID
		) StatsQ ON PPS.Mass_Tag_ID = StatsQ.Mass_Tag_ID
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error

	if DateDiff(second, @lastProgressUpdate, GetDate()) >= @ProgressUpdateIntervalThresholdSeconds
	Begin
		set @message = '...Processing: Populated ObsCount_CS2 in T_Mass_Tag_Peptide_Prophet_Stats (' + Convert(varchar(19), @myRowCount) + ' / ' + Convert(varchar(19), @RowCountUpdated) + ' PMT tags updated)'
		execute PostLogEntry 'Progress', @message, 'UpdateMassTagPeptideProphetStats'
		set @message = ''
		set @lastProgressUpdate = GetDate()
	End

	---------------------------------------------------
	-- Update stats for 3+ data
	---------------------------------------------------
	--
	UPDATE T_Mass_Tag_Peptide_Prophet_Stats
	SET ObsCount_CS3 = StatsQ.ObsCount,
		PepProphet_FScore_Max_CS3 = StatsQ.Peptide_Prophet_FScore_Maximum,
		PepProphet_Probability_Max_CS3 = StatsQ.Peptide_Prophet_Probability_Maximum,
		PepProphet_FScore_Avg_CS3 = StatsQ.Peptide_Prophet_FScore_Average
	FROM T_Mass_Tag_Peptide_Prophet_Stats PPS INNER JOIN
		(	SELECT  P.Mass_Tag_ID, 
					COUNT(*) AS ObsCount,
					MAX(SD.Peptide_Prophet_FScore) AS Peptide_Prophet_FScore_Maximum, 
    				MAX(SD.Peptide_Prophet_Probability) AS Peptide_Prophet_Probability_Maximum,
    				AVG(SD.Peptide_Prophet_FScore) AS Peptide_Prophet_FScore_Average
			FROM T_Peptides P INNER JOIN
				 T_Score_Discriminant SD ON P.Peptide_ID = SD.Peptide_ID
			WHERE P.Charge_State >= 3
			GROUP BY P.Mass_Tag_ID
		) StatsQ ON PPS.Mass_Tag_ID = StatsQ.Mass_Tag_ID	
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error

	if DateDiff(second, @lastProgressUpdate, GetDate()) >= @ProgressUpdateIntervalThresholdSeconds
	Begin
		set @message = '...Processing: Populated ObsCount_CS3 in T_Mass_Tag_Peptide_Prophet_Stats (' + Convert(varchar(19), @myRowCount) + ' / ' + Convert(varchar(19), @RowCountUpdated) + ' PMT tags updated)'
		execute PostLogEntry 'Progress', @message, 'UpdateMassTagPeptideProphetStats'
		set @message = ''
		set @lastProgressUpdate = GetDate()
	End

	-----------------------------------------------
	-- Post a message to the log
	-----------------------------------------------
	Set @message = 'Updated ' + Convert(varchar(12), @RowCountUpdated) + ' rows in T_Mass_Tag_Peptide_Prophet_Stats'

	EXEC PostLogEntry 'Normal', @message, 'UpdateMassTagPeptideProphetStats'
		 
Done:
	Return @myError


GO

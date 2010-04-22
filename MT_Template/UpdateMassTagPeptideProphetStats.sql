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
**			06/16/2008 mem - Now populating column Cleavage_State_Max
**			03/09/2008 mem - Updated queries to compute ObsCount values for distinct combinations of dataset, scan, charge, and peptide
**    
*****************************************************/
(
	@RowCountUpdated int = 0 output,
	@message varchar(255) = '' output,
	@previewSql tinyint = 0
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
	
	Declare @ChargeState tinyint
	Declare @ChargeStateMax tinyint
	
	Declare @S varchar(2048)
	Declare @CSText varchar(6)
	
	---------------------------------------------------
	-- Clear the outputs
	---------------------------------------------------
	set @RowCountUpdated = 0
	set @message = ''
	set @previewSql = IsNull(@previewSql, 0)
	
	If @previewSql = 0
	Begin -- <a>
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
		INSERT INTO T_Mass_Tag_Peptide_Prophet_Stats (Mass_Tag_ID, Cleavage_State_Max)
		SELECT Mass_Tag_ID, Cleavage_State_Max
		FROM T_Mass_Tags
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error

		Set @RowCountUpdated = @myRowCount

		If @RowCountUpdated = 0
		Begin
			Set @message = 'T_Mass_Tags is empty; unable to populate T_Mass_Tag_Peptide_Prophet_Stats'
			execute PostLogEntry 'Warning', @message, 'UpdateMassTagPeptideProphetStats'

			Goto Done
		End

	End	 -- </a>
	Else
		Set @RowCountUpdated = 1
		
	---------------------------------------------------
	-- Update stats for 1+, 2+, then >=3+ data
	---------------------------------------------------
	--
	
	Set @ChargeState = 1
	Set @ChargeStateMax = 3
	
	While @ChargeState <= @ChargeStateMax
	Begin -- <b>
	
		Set @CSText = Convert(varchar(6), @ChargeState)
		
		Set @S = ''
		
		Set @S = @S + ' UPDATE T_Mass_Tag_Peptide_Prophet_Stats'
		Set @S = @S + ' SET ObsCount_CS' + @CSText + ' = StatsQ.ObsCount,'
		Set @S = @S +     ' PepProphet_FScore_Max_CS' + @CSText + ' = StatsQ.Peptide_Prophet_FScore_Maximum,'
		Set @S = @S +     ' PepProphet_Probability_Max_CS' + @CSText + ' = StatsQ.Peptide_Prophet_Probability_Maximum,'
		Set @S = @S +     ' PepProphet_FScore_Avg_CS' + @CSText + ' = StatsQ.Peptide_Prophet_FScore_Average'
		Set @S = @S + ' FROM T_Mass_Tag_Peptide_Prophet_Stats PPS INNER JOIN'
		Set @S = @S +     ' ( SELECT Mass_Tag_ID,'
		Set @S = @S +              ' COUNT(*) AS ObsCount,'
		Set @S = @S +              ' MAX(Peptide_Prophet_FScore) AS Peptide_Prophet_FScore_Maximum,'
		Set @S = @S +              ' MAX(Peptide_Prophet_Probability) AS Peptide_Prophet_Probability_Maximum,'
		Set @S = @S +              ' AVG(Peptide_Prophet_FScore) AS Peptide_Prophet_FScore_Average'
		Set @S = @S +       ' FROM ( SELECT TAD.Dataset,'
		Set @S = @S +                     ' P.Scan_Number,'
		Set @S = @S +                     ' P.Mass_Tag_ID,'
		Set @S = @S +                     ' MAX(SD.Peptide_Prophet_FScore) AS Peptide_Prophet_FScore,'
		Set @S = @S +                     ' MAX(SD.Peptide_Prophet_Probability) AS Peptide_Prophet_Probability'
		Set @S = @S +              ' FROM T_Peptides P'
		Set @S = @S +                   ' INNER JOIN T_Score_Discriminant SD'
		Set @S = @S +                     ' ON P.Peptide_ID = SD.Peptide_ID'
		Set @S = @S +                   ' INNER JOIN T_Analysis_Description TAD'
		Set @S = @S +                     ' ON P.Analysis_ID = TAD.Job'
		
		If @ChargeState < @ChargeStateMax
			Set @S = @S +                   ' WHERE (P.Charge_State >= ' + @CSText + ')'
		Else
			Set @S = @S +                   ' WHERE (P.Charge_State = ' + @CSText + ')'
			
		Set @S = @S +              ' GROUP BY P.Mass_Tag_ID, TAD.Dataset, P.Scan_Number '
		Set @S = @S +            ' ) UniqueStatsQ'
		Set @S = @S +       ' GROUP BY Mass_Tag_ID'
		Set @S = @S +     ' ) StatsQ ON PPS.Mass_Tag_ID = StatsQ.Mass_Tag_ID'
		
		If @previewSql <> 0
			Print @S
		Else
		Begin
			Exec (@S)
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error

			If DateDiff(second, @lastProgressUpdate, GetDate()) >= @ProgressUpdateIntervalThresholdSeconds
			Begin
				set @message = '...Processing: Populated ObsCount_CS' + @CSText + ' in T_Mass_Tag_Peptide_Prophet_Stats (' + Convert(varchar(19), @myRowCount) + ' / ' + Convert(varchar(19), @RowCountUpdated) + ' PMT tags updated)'
				execute PostLogEntry 'Progress', @message, 'UpdateMassTagPeptideProphetStats'
				set @message = ''
				set @lastProgressUpdate = GetDate()
			End
		End
				
		Set @ChargeState = @ChargeState + 1
	End -- </b>

	If @previewSql = 0
	Begin
		-----------------------------------------------
		-- Post a message to the log
		-----------------------------------------------
		Set @message = 'Updated ' + Convert(varchar(12), @RowCountUpdated) + ' rows in T_Mass_Tag_Peptide_Prophet_Stats'

		execute PostLogEntry 'Normal', @message, 'UpdateMassTagPeptideProphetStats'
	End
			 
Done:
	Return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[UpdateMassTagPeptideProphetStats] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[UpdateMassTagPeptideProphetStats] TO [MTS_DB_Lite] AS [dbo]
GO

/****** Object:  StoredProcedure [dbo].[CalculateMonoisotopicMassWrapper] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.CalculateMonoisotopicMassWrapper
/****************************************************
**
**	Desc: Calls the CalculateMonoisotopicMass SP,
**		  positing messages to T_Log_Entries at the start and end
**
**	Auth:	mem
**	Date:	07/20/2004
**			08/07/2004 mem - Updated PostLogEntry calls
**			02/04/2005 mem - Now recording the T_Sequence row count in T_Stats_History whenever new masses are calculated
**			11/28/2005 mem - Added output parameter @PeptidesProcessedCount
**			08/22/2006 mem - Now calling UpdateStatsHistory to update T_Stats_History
**    
*****************************************************/
(
	@SequencesToProcess int = 10000,			-- When greater than 0, then only processes the given number of sequences
	@PeptidesProcessedCount int = 0 OUTPUT		-- Returns the actual number of sequences processed
)
AS
	Set NoCount ON

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	Declare @message varchar(255),
			@RecomputeAll tinyint,
			@AbortOnUnknownSymbolError tinyint

	Declare @ForceStatsUpdate tinyint
	Set @ForceStatsUpdate = 0
	
	Set @message = 'Starting call to CalculateMonoisotopicMass; sequences to process: ' + convert(varchar(11), @SequencesToProcess)
	-- Exec PostLogEntry 'Normal', @message, 'CalculateMonoisotopicMassWrapper'
	
	Set @message = ''
	Set @PeptidesProcessedCount = 0
	Exec @PeptidesProcessedCount = CalculateMonoisotopicMass @message OUTPUT, @RecomputeAll, @AbortOnUnknownSymbolError, @SequencesToProcess

	If Len(@message) > 0
		Exec PostLogEntry 'Error', @message, 'CalculateMonoisotopicMassWrapper'

	Set @message = 'Mass calculation complete; sequences processed: ' + convert(varchar(11), @PeptidesProcessedCount)
	if @PeptidesProcessedCount > 0
	Begin
		Exec PostLogEntry 'Normal', @message, 'CalculateMonoisotopicMassWrapper'
		
		Set @ForceStatsUpdate = 1
	End
	
	Exec UpdateStatsHistory @ForceStatsUpdate
	
	Return 0

GO
GRANT VIEW DEFINITION ON [dbo].[CalculateMonoisotopicMassWrapper] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[CalculateMonoisotopicMassWrapper] TO [MTS_DB_Lite] AS [dbo]
GO

SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[CalculateMonoisotopicMassWrapper]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[CalculateMonoisotopicMassWrapper]
GO


CREATE PROCEDURE dbo.CalculateMonoisotopicMassWrapper
/****************************************************
**
**	Desc: Calls the CalculateMonoisotopicMass SP,
**		  positing messages to T_Log_Entries at the start and end
**
**	Parameters:
**	
**  Output:

**		Auth: mem
**		Date: 07/20/2004
**			  08/07/2004 mem - Updated PostLogEntry calls
**			  02/04/2005 mem - Now recording the T_Sequence row count in T_Stats_History whenever new masses are calculated
**			  11/28/2005 mem - Added output parameter @PeptidesProcessedCount
**    
*****************************************************/
	(
		@SequencesToProcess int = 10000,			-- When greater than 0, then only processes the given number of sequences
		@PeptidesProcessedCount int = 0 OUTPUT		-- Returns the actual number of sequences processed
	)
AS
	Set NoCount ON

	Declare @message varchar(255),
			@RecomputeAll tinyint,
			@AbortOnUnknownSymbolError tinyint

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
		
		INSERT INTO T_Stats_History (Sequence_Count)
		SELECT TableRowCount
		FROM V_Table_Row_Counts
		WHERE TableName = 'T_Sequence'
		
	End
	
	Return 0
	

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


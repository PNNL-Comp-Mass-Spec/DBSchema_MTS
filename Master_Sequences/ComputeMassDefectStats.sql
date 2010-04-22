/****** Object:  StoredProcedure [dbo].[ComputeMassDefectStats] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.ComputeMassDefectStats
/****************************************************
**
**	Desc: Computes mass defect stats based on the sequences present in T_Sequence
**
**	Return values: 0: success, otherwise, error code
** 
**	Auth:	mem
**	Date:	05/15/2006
**    
*****************************************************/
(
	@MassStart int = 500,
	@MassEnd int = 5000,
	@MassStepSize int = 100,
	@SamplingSize int = 10000,
	@ReplaceExistingStats tinyint = 0,
	@message varchar(255) = '' output
)
AS
	Set NoCount On

	Declare @myError int
	Declare @myRowCount int
	Set @myError = 0
	Set @myRowCount = 0

	Set @message = ''

	Declare @GenerateStats tinyint
	Declare @BinCountQueried int
	Declare @BinCountSkipped int
	Declare @ErrorMessageSuffix varchar(128)
	
	Set @BinCountQueried = 0
	Set @BinCountSkipped = 0

	------------------------------------------------
	-- Validate the inputs
	------------------------------------------------
	--
	Set @MassStepSize = IsNull(@MassStepSize, 100)
	If @MassStepSize < 10
		Set @MassStepSize = 100
	
	Set @MassStart = IsNull(@MassStart, 0)
	If @MassStart < 0
		Set @MassStart = 0
	
	Set @MassEnd = IsNull(@MassEnd, @MassStart + @MassStepSize)
	If @MassEnd < @MassStart + @MassStepSize
		Set @MassEnd = @MassStart + @MassStepSize

	Set @SamplingSize = IsNull(@SamplingSize, 1000)
	If @SamplingSize < 1000
		Set @SamplingSize = 1000
	
	Set @ReplaceExistingStats = IsNull(@ReplaceExistingStats, 0)
	
	------------------------------------------------
	-- Create the output table if missing
	------------------------------------------------
	--
	If Not Exists (Select * from sys.tables where name = 'T_Mass_Defect_Stats')
	Begin
		CREATE TABLE [dbo].[T_Mass_Defect_Stats](
			[Sampling_Size] [int] NOT NULL,
			[Mass_Start] [int] NOT NULL,
			[Mass_Defect_Bin] [real] NOT NULL,
			[Bin_Count] [int] NOT NULL,
			[Query_Date] [datetime] NOT NULL CONSTRAINT [DF_T_Mass_Defect_Stats_Query_Date]  DEFAULT (getdate()),
			 CONSTRAINT [PK_T_Mass_Defect_Stats] PRIMARY KEY CLUSTERED (
				[Sampling_Size] ASC,
				[Mass_Start] ASC,
				[Mass_Defect_Bin] ASC
			)
		)
	End
	 
	------------------------------------------------
	-- Generate the stats
	------------------------------------------------
	--
	Set @GenerateStats = 1
	While @MassStart < @MassEnd
	Begin
		Set @ErrorMessageSuffix = 'for Sampling_Size ' + Convert(varchar(12), @SamplingSize) + ' and Mass Start ' + Convert(varchar(12), @MassStart)

		If @ReplaceExistingStats <> 0
		Begin
			DELETE FROM T_Mass_Defect_Stats
			WHERE Sampling_Size = @SamplingSize AND Mass_Start = @MassStart
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
			--
			If @myError <> 0
			Begin
				Set @message = 'Error clearing data from T_Mass_Defect_Stats ' + @ErrorMessageSuffix
				Set @myError = 50000
				Goto Done
			End

		End
		Else
		Begin
			If Not Exists (SELECT * FROM T_Mass_Defect_Stats WHERE Sampling_Size = @SamplingSize AND Mass_Start = @MassStart)
				Set @GenerateStats = 1
			Else
				Set @GenerateStats = 0
		End

		If @GenerateStats = 1
		Begin
			INSERT INTO T_Mass_Defect_Stats(Sampling_Size, Mass_Start, Mass_Defect_Bin, Bin_COUNT)
			SELECT @SamplingSize As Sampling_Size, @MassStart As Mass_Start, Round(Mass_Defect, 2) As Mass_Defect_Bin, Count(*) as Bin_Count From (
				SELECT Mass, Bin_Count, Mass - Floor(Mass) As Mass_Defect From (
					SELECT Round(Monoisotopic_Mass, 2) As Mass, Count(*) As Bin_Count
					FROM T_Sequence
					WHERE Seq_ID <= @SamplingSize AND Monoisotopic_Mass BETWEEN @MassStart and @MassStart + @MassStepSize
					GROUP BY Round(Monoisotopic_Mass, 2)
				) InnerQ
			) OuterQ
			GROUP BY Round(Mass_Defect, 2)
			ORDER BY Round(Mass_Defect, 2)
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
			--
			If @myError <> 0
			Begin
				Set @message = 'Error querying T_Sequence ' + @ErrorMessageSuffix
				Set @myError = 50001
				Goto Done
			End
			
			Set @BinCountQueried = @BinCountQueried + 1
		End
		Else
			Set @BinCountSkipped = @BinCountSkipped + 1

		Set @MassStart = @MassStart + @MassStepSize
	End

	Set @message = 'Done querying T_Sequence for the mass defect stats; Query Count = ' + Convert(varchar(12), @BinCountQueried)
	If @ReplaceExistingStats = 0
		Set @message = @message + '; Query Count skipped = ' + Convert(varchar(12), @BinCountSkipped)
		
Done:
			
	Return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[ComputeMassDefectStats] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[ComputeMassDefectStats] TO [MTS_DB_Lite] AS [dbo]
GO

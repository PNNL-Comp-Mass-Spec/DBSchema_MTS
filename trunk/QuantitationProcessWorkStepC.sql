/****** Object:  StoredProcedure [dbo].[QuantitationProcessWorkStepC] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.QuantitationProcessWorkStepC
/****************************************************	
**  Desc: 
**
**  Return values: 0 if success, otherwise, error code
**
**  Auth:	mem
**	Date:	09/07/2006
**
****************************************************/
(
	@QuantitationID int,
	@NormalizeAbundances tinyint,				-- 1 to normalize, 0 to not normalize
	@NormalizeReplicateAbu tinyint,				-- 1 to normalize replicate abundances
	@StandardAbundanceMin float,				-- Used with normalization: minimum abundance
	@StandardAbundanceMax float,				-- Used with normalization: maximum abundance
	@StandardAbundanceRange float,

	@PctSmallDataToDiscard tinyint,							-- Percentage, between 0 and 99
	@PctLargeDataToDiscard tinyint,							-- Percentage, between 0 and 99
	@MinimumDataPointsForRegressionNormalization smallint,	-- Number, 2 or larger

	@message varchar(512)='' output
)
AS
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	-- Variables for regression-based normalization
	Declare @RegressionSourceID int, 
			@TopLevelFractionWork smallint,
			@FractionWork smallint,
			@ReplicateValue smallint


	Declare @StatSumXY float,
			@StatSumX float, 
			@StatSumY float, 
			@StatSumXX float, 
			@StatDataCount int,
			@StatDenominator float,
			@StatM float,
			@StatB float,
			@StatSql varchar(1024),
			@StatMathSummary varchar(1024),
			@StatsAreValid tinyint

	Declare @NumSmallDataToDiscard smallint,
			@NumLargeDataToDiscard smallint,
			@StatMinimumM float,
			@StatMaximumM float,
			@StatMinimumB float,
			@StatMaximumB float
			
	Set @StatMathSummary = ''
	Set @StatsAreValid = 0
	
	Set @StatMinimumM = 0.01									-- Minimum slope value
	Set @StatMaximumM = 100										-- Maximum slope value
	Set @StatMinimumB = -100									-- Minimum y-intercept value
	Set @StatMaximumB = 100										-- Maximum y-intercept value
	
	-----------------------------------------------------------
	-- Step 6
	--
	-- Normalize the abundances if requested
	-- We first use StandardAbundanceMax and StandardAbundanceMin to scale all of the data
	-- Then, for each fraction that has replicates, we normalize each of the replicates to the first replicate
	--
	-----------------------------------------------------------
	--
	
	-- Step 6a
	--
	If @NormalizeAbundances <> 0		-- <a> 
	 Begin
		Set @StandardAbundanceRange = @StandardAbundanceMax - @StandardAbundanceMin
		
		If @StandardAbundanceRange <= 0
			Set @StandardAbundanceRange = 1
		
		-- Each value is normalized by subtracting @StandardAbundanceMin, then
		--  dividing by @StandardAbundanceRange
		-- If the value minus @StandardAbundanceMin is less than 0, then the normalized
		--  abundance is simply 0.  The IsNull statement assures that no Null values
		-- are stored.

		UPDATE #UMCMatchResultsByJob
		SET MTAbundance = IsNull(	Case 
									When MTAbundance > @StandardAbundanceMin Then
										(MTAbundance - @StandardAbundanceMin) / @StandardAbundanceRange * 100
									Else 0
									End
									, 0)

		-- Step 6b
		--
		-- For each Fraction that has replicates, Normalize each of the replicates to the first replicate
		-- Do this by plotting the abundance of each mass tag in Replicate x (x = 2, 3, 4, etc.) vs. the abundance of the mass tag in Replicate 1
		-- and fitting a linear regression line, giving a line of the form y = m*x + b

		-- Normalizing Replicate Abundances is turned off for now
		Set @NormalizeReplicateAbu = 0
		If @NormalizeReplicateAbu <> 0	-- <b> 
		 Begin
			if exists (select * from dbo.sysobjects where id = object_id(N'[#RegressionSource]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
			drop table [#RegressionSource]
			
			CREATE TABLE #RegressionSource (
				[SourceID] int NOT NULL IDENTITY (1, 1),
				[TopLevelFraction] smallint NOT NULL ,
				[Fraction] smallint NOT NULL ,
				[ReplicateCount] smallint NOT NULL
			)

			if exists (select * from dbo.sysobjects where id = object_id(N'[#RegressionX]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
			drop table [#RegressionX]

			CREATE TABLE #RegressionX (
				[Mass_Tag_ID] int NOT NULL ,
				[Mass_Tag_Mods] [varchar](50) NOT NULL ,
				[MTAbundance] float NULL
			)
			CREATE INDEX #IX__TempTable__RegressionX ON #RegressionX([Mass_Tag_ID]) ON [PRIMARY]

			if exists (select * from dbo.sysobjects where id = object_id(N'[#RegressionY]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
			drop table [#RegressionY]

			CREATE TABLE #RegressionY (
				[Mass_Tag_ID] int NOT NULL ,
				[Mass_Tag_Mods] [varchar](50) NOT NULL ,
				[MTAbundance] float NULL
			)
			CREATE INDEX #IX__TempTable__RegressionY ON #RegressionY([Mass_Tag_ID]) ON [PRIMARY]

			if exists (select * from dbo.sysobjects where id = object_id(N'[#RegressionReplicateValues]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
			drop table [#RegressionReplicateValues]

			CREATE TABLE #RegressionReplicateValues (
				[Replicate] smallint NOT NULL
			)

			if exists (select * from dbo.sysobjects where id = object_id(N'[#RegressionStats]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
			drop table [#RegressionStats]

			CREATE TABLE #RegressionStats (
				[SumXY] float,
				[SumX] float,
				[SumY] float,
				[SumXX] float,
				[DataCount] int
			)

			-- Populate #RegressionSource
			
			INSERT INTO #RegressionSource
					(TopLevelFraction, Fraction, ReplicateCount)
			SELECT	TopLevelFraction, Fraction,
					Max([Replicate]) - Min([Replicate]) + 1
			FROM #UMCMatchResultsByJob
			GROUP BY TopLevelFraction, Fraction
			
			-- Remove any entries in #RegressionSource with a ReplicateCount of 1 or smaller
			DELETE FROM #RegressionSource
			WHERE ReplicateCount <=1
				
			Set @RegressionSourceID = 0
			While @RegressionSourceID >= 0		-- <c>
			Begin
				Set @RegressionSourceID = -1
		 
				-- Loop through the entries remaining in #RegressionSource and normalize the replicates for each one
				SELECT TOP 1 
						@RegressionSourceID = SourceID, 
						@TopLevelFractionWork = TopLevelFraction,
						@FractionWork = Fraction
				FROM #RegressionSource
				ORDER BY TopLevelFraction, Fraction
				--
				SELECT @myRowCount = @@RowCount
				
				If @myRowCount = 1 And @RegressionSourceID >= 0		-- <d>
				 Begin
					-- Obtain a list of the Replicate values for this TopLevelFraction and Fraction
					TRUNCATE TABLE #RegressionReplicateValues
					
					INSERT INTO #RegressionReplicateValues
							([Replicate])
					SELECT	[Replicate]
					FROM	#UMCMatchResultsByJob
					WHERE	TopLevelFraction = @TopLevelFractionWork AND 
							Fraction = @FractionWork
					GROUP BY [Replicate]
					ORDER BY [Replicate]
					
					-- Look up the minimum Replicate value
					SET @ReplicateValue = Null
					SELECT @ReplicateValue = MIN([Replicate]) 
					FROM #RegressionReplicateValues
					
					-- Populate #RegressionX
					TRUNCATE TABLE #RegressionX
					
					INSERT INTO #RegressionX
						(Mass_Tag_ID, Mass_Tag_Mods, MTAbundance)
					SELECT	Mass_Tag_ID, Mass_Tag_Mods, MTAbundance
					FROM	#UMCMatchResultsByJob
					WHERE	TopLevelFraction = @TopLevelFractionWork AND 
							Fraction = @FractionWork AND
							[Replicate] = @ReplicateValue

					-- Remove the minimum Replicate value from #RegressionReplicateValues
					DELETE FROM #RegressionReplicateValues
					WHERE [Replicate] = @ReplicateValue
					
					Set @ReplicateValue = 0
					While @ReplicateValue >=0	-- <e>
					Begin
						-- Look up the new minimum Replicate value
						SET @ReplicateValue = -1
						SELECT @ReplicateValue = MIN([Replicate])
						FROM #RegressionReplicateValues
						--
						SELECT @myRowCount = @@RowCount
						
						If @myRowCount = 1 And @ReplicateValue >=0		-- <f>
						Begin
							-- Populate #RegressionY
							TRUNCATE TABLE #RegressionY
							
							INSERT INTO #RegressionY
								(Mass_Tag_ID, Mass_Tag_Mods, MTAbundance)
							SELECT	Mass_Tag_ID, Mass_Tag_Mods, MTAbundance
							FROM	#UMCMatchResultsByJob
							WHERE	TopLevelFraction = @TopLevelFractionWork AND 
									Fraction = @FractionWork AND
									[Replicate] = @ReplicateValue
							
							-- Update @StatMathSummary
							If Len(@StatMathSummary) > 0
								Set @StatMathSummary = @StatMathSummary + ';'
							
							Set @StatMathSummary = @StatMathSummary + 'T' + LTrim(RTrim(convert(varchar(9), @TopLevelFractionWork)))
							Set @StatMathSummary = @StatMathSummary + 'F' + LTrim(RTrim(convert(varchar(9), @FractionWork)))
							Set @StatMathSummary = @StatMathSummary + 'R' + LTrim(RTrim(convert(varchar(9), @ReplicateValue))) + '='

							-- Perform the regression
							-- ToDo: Figure out how to compute the regression, fixing b = 0 (for y = mx + b)
							--
							-- Use the following to select the data to perform the regression on
							-- @PctDataToUseForNormalization is a value between 1 and 100

							TRUNCATE TABLE #RegressionStats
													
							SELECT @StatDataCount = Count(#RegressionX.MTAbundance)
							FROM #RegressionX INNER JOIN
						 		#RegressionY ON
						 		#RegressionX.Mass_Tag_ID = #RegressionY.Mass_Tag_ID
						 		AND
						 		#RegressionX.Mass_Tag_Mods = #RegressionY.Mass_Tag_Mods

							-- Compute the number of data points to discard from the beginning and end of the data (as sorted by intensity)
							Set @NumSmallDataToDiscard = @StatDataCount * (@PctSmallDataToDiscard/100.0)
							Set @NumLargeDataToDiscard = @StatDataCount * (@PctLargeDataToDiscard/100.0)
							If @NumSmallDataToDiscard < 0
								Set @NumSmallDataToDiscard = 0
							If @NumLargeDataToDiscard < 0
								Set @NumLargeDataToDiscard = 0
							
							-- Reset @StatsAreValid to 0
							Set @StatsAreValid = 0

							-- See if enough data points are present for normalization using regression
							If @StatDataCount - @NumSmallDataToDiscard - @NumLargeDataToDiscard >= @MinimumDataPointsForRegressionNormalization		-- <g>
							Begin
															
								Set @StatSql = ''
								Set @StatSql = @StatSql + ' INSERT INTO #RegressionStats (SumXY, SumX, SumY, SumXX, DataCount)'
								Set @StatSql = @StatSql + ' SELECT SUM(AbuX*AbuY), SUM(AbuX), SUM(AbuY), SUM(AbuX*AbuX), Count(AbuX)'
								Set @StatSql = @StatSql + '	FROM'
								Set @StatSql = @StatSql + '      (SELECT TOP ' + Convert(varchar(9), @StatDataCount - @NumLargeDataToDiscard - @NumSmallDataToDiscard) + ' DataToUse.AbuX, DataToUse.AbuY'
								Set @StatSql = @StatSql + '       FROM'
								Set @StatSql = @StatSql + '  (SELECT TOP ' + Convert(varchar(9), @StatDataCount - @NumSmallDataToDiscard) + ' #RegressionX.MTAbundance AS AbuX,'
								Set @StatSql = @StatSql + '             #RegressionY.MTAbundance AS AbuY'
								Set @StatSql = @StatSql + '          FROM #RegressionX INNER JOIN'
								Set @StatSql = @StatSql + '             #RegressionY ON'
								Set @StatSql = @StatSql + '             #RegressionX.Mass_Tag_ID = #RegressionY.Mass_Tag_ID'
								Set @StatSql = @StatSql + '               AND'
								Set @StatSql = @StatSql + '             #RegressionX.Mass_Tag_Mods = #RegressionY.Mass_Tag_Mods'
								Set @StatSql = @StatSql + '          ORDER BY #RegressionX.MTAbundance DESC) As DataToUse'
								Set @StatSql = @StatSql + '       ORDER BY DataToUse.AbuX ASC) As DataToUseOuter'
		
								Exec (@StatSql)
								
								SELECT TOP 1 @StatSumXY = SumXY, @StatSumX = SumX, @StatSumY = SumY, @StatSumXX = SumXX, @StatDataCount = DataCount
								FROM #RegressionStats
								
								Set @StatDenominator = @StatDataCount * @StatSumXX - @StatSumX * @StatSumX
								
								If IsNull(@StatDenominator,0) <> 0		-- <h>
								Begin
									-- Calculate the slope and intercept (for y = mx + b)
									-- It would be better to compute simply a slope (for y = mx, with b fixed at 0); don't know how to do this
									
									Set @StatM = (@StatDataCount * @StatSumXY - @StatSumX * @StatSumY) / @StatDenominator
									Set @StatB = (@StatSumY * @StatSumXX - @StatSumX * @StatSumXY) / @StatDenominator
									
									-- If StatM and StatB are within the accepted limits, then normalize the data for this replicate
									If @StatM <> 0 And @StatM >= @StatMinimumM And @StatM <= @StatMaximumM And @StatB >= @StatMinimumB And @StatB <= @StatMaximumB		-- <i>
									Begin
										UPDATE #UMCMatchResultsByJob
										-- SET		MTAbundance = (MTAbundance - @StatB) / @StatM
										SET		MTAbundance = MTAbundance / @StatM
										WHERE	TopLevelFraction = @TopLevelFractionWork AND 
												Fraction = @FractionWork AND
												[Replicate] = @ReplicateValue
										
										Set @StatsAreValid = 1
									End		-- <i>
								End		-- <h>
							End	-- <g>

							If @StatsAreValid = 0
							Begin
								Set @StatMathSummary = @StatMathSummary + '0,0'
							End
							Else
							Begin
								Set @StatMathSummary = @StatMathSummary + LTrim(RTrim(Convert(varchar(19), Round(@StatM,5)))) + ','
								Set @StatMathSummary = @StatMathSummary + LTrim(RTrim(Convert(varchar(19), Round(@StatB,5))))
							End
								
							-- Remove the minimum Replicate value
							DELETE FROM #RegressionReplicateValues
							WHERE [Replicate] = @ReplicateValue
							
						End 	-- <f>
					End		-- <e>
					
					-- Remove this combination of TopLevelFraction and Fraction from #RgressionSource			
					DELETE FROM #RegressionSource
					WHERE SourceID = @RegressionSourceID
				
				End 	-- <d>
			End 	-- <c>
		 End	-- <b>
	 End	-- <a>

	UPDATE T_Quantitation_Description
	SET	ReplicateNormalizationStats = @StatMathSummary
	WHERE Quantitation_ID = @QuantitationID

Done:
	Return @myError


GO

/****** Object:  StoredProcedure [dbo].[QRGenerateCrossTabSql] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.QRGenerateCrossTabSql
/****************************************************	
**  Desc:	Parses the values in @QuantitationIDList (separated by commas)
**		     to construct appropriate Sql for a pivot query
**			Also populates @QuantitationIDListSql
**			If @SeparateReplicateDataIDs = 1, then for QuantitationID's involving 
**           replicates, determines the most appropriate individual QuantitationID 
**           values for each of the replicates
**			Lastly, populates @ERValuesPresent and @ModsPresent
**		     by calling QRLookupOptionalColumns
**
**			Note: the calling procedure needs to create this table, which is populated by this SP using @QuantitationIDList:
**
**			CREATE TABLE #TmpQIDSortInfo (
**				SortKey int identity (1,1),
**				QID int NOT NULL)
**
**  Return values:	0 if success, otherwise, error code 
**
**  Parameters: QuantitationID List to parse
**
**  Auth:	mem
**	Date:	07/30/2003
**			08/14/2003
**			08/15/2003
**			08/18/2003
**			08/26/2003
**			09/16/2003
**          12/13/2003 mem - Added logic to assure that @PivotColumnsSql and @CrossTabSqlGroupBy stay under 7000 and 8000 characters, respectively
**			06/06/2004 mem - Now populating @ERValuesPresent, @DynamicModsPresent, and @StaticModsPresent
**			07/01/2004 mem - Fixed bug during population of @QIDListUnique
**			10/05/2004 mem - Updated for new MTDB schema
**			05/24/2005 mem - Now checking for invalid QuantitationID values in @QuantitationIDList
**			09/22/2005 mem - Added parameters @QuantitationIDListClean and updated to use QRCollapseToUniqueList
**			11/28/2006 mem - Fixed bug that failed to populate @QuantitationIDListToUseClean if @SeparateReplicateDataIDs = 0
**						   - Added parameter @SkipCrossTabSqlGeneration
**			12/01/2006 mem - Now using udfParseDelimitedIntegerList to parse @QIDListUnique
**			06/04/2007 mem - Increased several variables to varchar(max)
**			06/05/2007 mem - Updated for use with the PIVOT operator to create the crosstab
**						   - Now reporting [Observation Count] in @CrossTabSqlGroupBy
**			01/24/2008 mem - Added column @DateStampHeaderColumn
**			08/12/2008 mem - Added column @XTandemDataPresent
**
****************************************************/
(
	@QuantitationIDList varchar(max),					-- Comma separated list of Quantitation ID's (duplicates are allowed)
	@SourceColName varchar(128),
	@AggregateColName varchar(128) = 'AbuAvg', 
	@AverageAcrossColumnsEnabled tinyint = 0,			-- If 1, then record Null when missing, otherwise record '''' when missing
	@SeparateReplicateDataIDs tinyint = 1,				-- Only applies to the generation of @QuantitationIDListSql and @CrossTabSqlGroupBy
	@SortMode tinyint = 2,								-- 0=Unsorted, 1=QID, 2=SampleName, 3=Comment, 4=Job (first job if more than one job), 5=Dataset Acq_Time_Start
	@SkipCrossTabSqlGeneration tinyint = 0,				-- If 1, then doesn't populate @CrossTabSqlGroupBy, which allows one to process longer lists of QID values
	@PivotColumnsSql varchar(max) = '' Output,
	@CrossTabSqlGroupBy varchar(max) = '' Output,
	@QuantitationIDListSql varchar(max) = '' Output,	-- List of QID values determined using @QuantitationIDList
	@ERValuesPresent tinyint=0 Output,
	@ModsPresent tinyint=0 Output,
	@QuantitationIDListClean varchar(max)='' Output,	-- Reduction of @QuantitationIDList into a unique list of numbers; additionally, is not affected by @SeparateReplicateDataIDs in that @QuantitationIDListClean will still contain replicate-based QIDs if present in @QuantitationIDList
	@DateStampHeaderColumn tinyint=0,
	@XTandemDataPresent tinyint=0 Output
)
AS
	Set NoCount On

	Declare @myError int
	Declare @myRowcount int
	Set @myRowcount = 0
	Set @myError = 0

	Declare @CommaLoc int,
			@MDIDCommaLoc int,
			@MatchCount int,
			@ReplicateCount int

	Set @CommaLoc = 0
	Set @MDIDCommaLoc = 0
	Set @MatchCount = 0
	Set @ReplicateCount = 0

	-- Clear the outputs
	Set @PivotColumnsSql = ''
	Set @CrossTabSqlGroupBy = ''
	Set @QuantitationIDListSql = ''
	Set @ERValuesPresent = 0
	Set @ModsPresent = 0
	Set @XTandemDataPresent = 0
	Set @QuantitationIDListClean = ''


	Declare	@WorkingQIDList varchar(max),
			@QIDListUnique varchar(max),
			@QuantitationIDText varchar(19),
			@WorkingList varchar(max),
			@MDIDList varchar(max),
			@MDID varchar(19),
			@CorrespondingQIDList varchar(max),
			@PotentialQIDValue varchar(19),
			@JobList varchar(max),
			@JobListCount int,
			@QIDColName varchar(64),
			@AggregateFn varchar(max),
			@AggregateFnSum varchar(max),
			@AggregateFnCount varchar(max),
			@TimeStamp varchar(64)

	Declare @FractionHighestAbuToUse decimal(9,8),
			@NormalizeToStandardAbundances tinyint,
			@StandardAbundanceMin float,
			@StandardAbundanceMax float,
			@QuantitationID int,
			@CurrentSortKey int,
			@continue tinyint,
			@DatasetDateMinimum datetime

	-- Assure that the following are blank
	Set @AggregateFn = ''
	Set @AggregateFnSum = ''
	Set @AggregateFnCount = ''
	
	-- Copy from @QuantationIDList into @WorkingQIDList and add a trailing comma (to make parsing easier)
	Set @WorkingQIDList = @QuantitationIDList + ','
	
	If @SeparateReplicateDataIDs = 0
	Begin
		Set @QuantitationIDListClean = @QuantitationIDList
	End
	Else
	Begin -- <a>
		-- Examine T_Quantitation_MDIDs to determine the individual Quantitation_ID numbers 
		-- for the MDIDs defined for each  

		-- Copy from @WorkingQIDList into @WorkingList
		Set @WorkingList = @WorkingQIDList
	
		-- Clear @WorkingQIDList and @QuantitationIDListClean
		Set @WorkingQIDList = ''
		Set @QuantitationIDListClean = ''

		Set @CommaLoc = CharIndex(',', @WorkingList)
		While @CommaLoc > 1
		Begin -- <b>

			Set @QuantitationIDText = LTrim(Left(@WorkingList, @CommaLoc-1))
			Set @WorkingList = SubString(@WorkingList, @CommaLoc+1, Len(@WorkingList))
			
			If IsNumeric(@QuantitationIDText) = 1
			Begin -- <c>
				-- This is a valid QID value; append to @QuantitationIDListClean
				Set @QuantitationIDListClean = @QuantitationIDListClean + @QuantitationIDText + ','
				
				-- Determine if this is actually a QuantitationID with replicates
				-- Do this using the following query, then checking @@RowCount
				-- Simultaneously, generate a comma delimited list of the MDIDs for this QuantitationID
				Set @MDIDList = ''
				SELECT @MDIDList = @MDIDList + Convert(varchar(19), MD_ID) + ','
				FROM T_Quantitation_MDIDs
				WHERE Quantitation_ID = @QuantitationIDText
				ORDER BY [Replicate]
				--
				Set @ReplicateCount = @@RowCount
			
				If @ReplicateCount > 0
				Begin -- <d>
					If @ReplicateCount <= 1
						Set @CorrespondingQIDList = @QuantitationIDText + ','
					Else
					Begin -- <e>

						Set @CorrespondingQIDList = ''

						-- Look up the settings used for this QuantitationID
						SELECT	@FractionHighestAbuToUse = Fraction_Highest_Abu_To_Use, 
								@NormalizeToStandardAbundances = Normalize_To_Standard_Abundances, 
								@StandardAbundanceMin = Standard_Abundance_Min, 
								@StandardAbundanceMax = Standard_Abundance_Max
						FROM T_Quantitation_Description
						WHERE Quantitation_ID = @QuantitationIDText
						
						-- Generate a comma delimited list of the most appropriate QuantitationID
						--  for each MDID in @MDIDList
						Set @MDIDCommaLoc = CharIndex(',', @MDIDList)
						While @MDIDCommaLoc > 1
						Begin -- <f>
							Set @MDID = LTrim(Left(@MDIDList, @MDIDCommaLoc-1))
							Set @MDIDList = SubString(@MDIDList, @MDIDCommaLoc+1, Len(@MDIDList))
	
							If IsNumeric(@MDID) = 1
							Begin -- <g>
								Set @PotentialQIDValue = ''

								-- First try to find a corresponding QuantitationID that matches the 
								-- quantitation settings for this replicate-based entry and the given MDID
								SELECT TOP 1 @PotentialQIDValue = Convert(varchar(19), Quantitation_ID)
								FROM (	SELECT	T_Quantitation_MDIDs.Quantitation_ID, 
												COUNT(T_Quantitation_MDIDs.Replicate) AS ReplicateCount,
												MAX(T_Quantitation_MDIDs.MD_ID) AS MDID
										FROM	T_Quantitation_Description INNER JOIN
												T_Quantitation_MDIDs ON 
												T_Quantitation_Description.Quantitation_ID = T_Quantitation_MDIDs.Quantitation_ID
										WHERE	Fraction_Highest_Abu_To_Use = @FractionHighestAbuToUse AND 
												Normalize_To_Standard_Abundances = @NormalizeToStandardAbundances AND 
												Standard_Abundance_Min = @StandardAbundanceMin AND 
												Standard_Abundance_Max = @StandardAbundanceMax
										GROUP BY T_Quantitation_MDIDs.Quantitation_ID) AS SubQuery
								WHERE ReplicateCount = 1 AND MDID = @MDID
								ORDER BY Quantitation_ID DESC

								If Len(@PotentialQIDValue) = 0
									-- If no matches are found, then use the following query to find the 
									--  most recent QuantitationID for the given MDID
									SELECT TOP 1 @PotentialQIDValue = Convert(varchar(19), Quantitation_ID)
									FROM (	SELECT	Quantitation_ID, 
													COUNT(MD_ID) AS ReplicateCount, 
													MAX(MD_ID) AS MDID
											FROM dbo.T_Quantitation_MDIDs
											GROUP BY Quantitation_ID) AS SubQuery
									WHERE ReplicateCount = 1 AND MDID = @MDID
									ORDER BY Quantitation_ID DESC

								If IsNumeric(@PotentialQIDValue) = 1
									Set @CorrespondingQIDList = @CorrespondingQIDList + @PotentialQIDValue + ','

							End -- </g>

							Set @MDIDCommaLoc = CharIndex(',', @MDIDList)
						End -- </f>
					End -- </e>
					
					Set @WorkingQIDList = @WorkingQIDList + @CorrespondingQIDList
				End -- </d>
			End -- </c>

			Set @CommaLoc = CharIndex(',', @WorkingList)
		End -- </b>		
	End -- </a>

	-- Make sure no duplicates are present in @WorkingQIDList
	Exec QRCollapseToUniqueList @WorkingQIDList, @QIDListUnique OUTPUT
	
	-- Make sure @QIDListUnique is not zero-length
	If Len(IsNull(@QIDListUnique, '')) = 0
		Set @QIDListUnique = '0,'
	
	-- Make sure @QIDListUnique ends in a comma
	If SubString(@QIDListUnique, Len(@QIDListUnique), 1) <> ','
		Set @QIDListUnique = @QIDListUnique + ','

	-- Make sure no duplicates are present in @QuantitationIDListClean
	Exec QRCollapseToUniqueList @QuantitationIDListClean, @QuantitationIDListClean OUTPUT
		

	--------------------------------------------------------------
	-- Populate #TmpQIDValues with the values in @QIDListUnique
	-- If @QIDListUnique contains any non-numeric values, then this will throw an error
	--------------------------------------------------------------
	--
	CREATE TABLE #TmpQIDValues (
		UniqueRowID int identity(1,1),
		QID int NOT NULL
	)
	--
	INSERT INTO #TmpQIDValues (QID)
	SELECT Value
	FROM dbo.udfParseDelimitedIntegerList(@QIDListUnique, ',')
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	
	If @myError <> 0
	Begin
		Print 'Error parsing @QIDListUnique with udfParseDelimitedIntegerList: ' + Convert(varchar(12), @myError)
		Goto Done
	End

	If @myRowCount = 0
	Begin
		-- No Data Found
		Set @myError = 50001
		Goto Done
	End

	--------------------------------------------------------------
	-- Populate #TmpQIDSortInfo based on @SortMode (using #TmpQIDValues)
	--------------------------------------------------------------
	Exec @myError = QRDetermineSortOrder @SortMode
	If @myError <> 0
	Begin
		Print 'Error calling QRDetermineSortOrder: ' + Convert(varchar(12), @myError)
		Goto Done
	End
		
	--------------------------------------------------------------
	-- Construct @QuantitationIDListSql (unless @SkipCrossTabSqlGeneration <> 0)
	-- Do this by iterating through #TmpQIDSortInfo
	-- In addition, determine if any of the Quantitation ID's have any ER values or modifications
	--------------------------------------------------------------

	Set @CurrentSortKey = -1
	Set @continue = 1
	While @continue = 1
	Begin -- <a>
		SELECT TOP 1 @QuantitationID = QID, @CurrentSortKey = SortKey
		FROM #TmpQIDSortInfo
		WHERE SortKey > @CurrentSortKey
		ORDER BY SortKey
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		If @myRowCount <> 1
			Set @continue = 0
		Else
		Begin -- <b>
			Set @QuantitationIDText = Convert(varchar(19), @QuantitationID)

			If Len(@PivotColumnsSql) > 0
				Set @PivotColumnsSql = @PivotColumnsSql + ','

			If Len(@QuantitationIDListSql) > 0
				Set @QuantitationIDListSql = @QuantitationIDListSql + ','
		
			If @DateStampHeaderColumn = 0
			Begin
				
				-- Lookup the job numbers that this QuantitationID corresponds to
				Set @JobList = ''
				
				SELECT	@JobList = @JobList + ',' + LTrim(RTrim(Convert(varchar(19), MMD.MD_Reference_Job)))
				FROM	T_Quantitation_Description QD INNER JOIN
						T_Quantitation_MDIDs QMDIDs ON QD.Quantitation_ID = QMDIDs.Quantitation_ID INNER JOIN
						T_Match_Making_Description MMD ON QMDIDs.MD_ID = MMD.MD_ID
				WHERE	QD.Quantitation_ID = @QuantitationID
				ORDER BY MD_Reference_Job
				--
				Set @JobListCount = @@RowCount
				
				If @JobListCount <= 0
					-- This shouldn't happen
					Set @JobList = 'Job 0'
				Else
				Begin
					-- Remove the leading ,
					Set @JobList = SubString(@JobList, 2, Len(@JobList)-1)
					
					If @JobListCount = 1
						-- Just one job
						Set @JobList = 'Job ' + @JobList
					Else
						-- Multiple jobs
						Set @JobList = 'Jobs ' + @JobList
				End
				
				-- Make sure @JobList isn't too long
				If Len(@JobList) > 45
					Set @JobList = SubString(@JobList, 1, 42) + '...'
				
				-- Define @QIDColName, surrounding with brackets, and appending a space
				Set @QIDColName = '[' + @JobList + ' (QID' + @QuantitationIDText + ')]'
			End
			Else
			Begin
				-- Generate a datestamp based on the minimum Dataset Date associated with this QID
				
				Set @DatasetDateMinimum = Null
				
				SELECT @DatasetDateMinimum = MIN(ISNULL(FAD.Dataset_Acq_Time_Start, FAD.Dataset_Created_DMS))
				FROM T_Quantitation_Description QD INNER JOIN 
					 T_Quantitation_MDIDs QMD ON QD.Quantitation_ID = QMD.Quantitation_ID INNER JOIN 
					 T_Match_Making_Description MMD ON QMD.MD_ID = MMD.MD_ID INNER JOIN 
					 T_FTICR_Analysis_Description FAD ON MMD.MD_Reference_Job = FAD.Job
				WHERE QD.Quantitation_ID = @QuantitationID
				GROUP BY QD.Quantitation_ID
				
				Set @DatasetDateMinimum = IsNull(@DatasetDateMinimum, '1/1/2000')
				Set @TimeStamp = dbo.udfTimeStampText(@DatasetDateMinimum)
				
				-- Define @QIDColName, surrounding with brackets, and appending a space
				Set @QIDColName = '[' + @TimeStamp + ' (QID' + @QuantitationIDText + ')]'
				
			End
			
			-- The PIVOT command requires the values for the IN clause to be surrounded with square brackets
			Set @QuantitationIDListSql = @QuantitationIDListSql + '[' + @QuantitationIDText + ']'
			
			If @SkipCrossTabSqlGeneration = 0
			Begin -- <d>
				-- Add the next term onto @PivotColumnsSql
				If @AverageAcrossColumnsEnabled <> 0
					Set @PivotColumnsSql = @PivotColumnsSql + '[' + @QuantitationIDText + '] AS ' + @QIDColName
				Else
					Set @PivotColumnsSql = @PivotColumnsSql + 'IsNull([' + @QuantitationIDText + '],'''') AS ' + @QIDColName
				
				-- Goal: @AggregateFn = '(' + @AggregateFnSum + ') / (' + @AggregateFnCount + ') AS ' + @AggregateColName
				If Len(@CrossTabSqlGroupBy) > 0
				Begin
					Set @CrossTabSqlGroupBy = @CrossTabSqlGroupBy + ','
					Set @AggregateFnSum = @AggregateFnSum + '+'
					Set @AggregateFnCount = @AggregateFnCount + '+'
				End

				-- Add the next term onto @CrossTabSqlGroupBy
				Set @CrossTabSqlGroupBy = @CrossTabSqlGroupBy + 'ISNULL(MAX(' + @QIDColName + '),'''') AS ' + @QIDColName
			
				-- Add the next term onto @AggregateFnSum
				Set @AggregateFnSum = @AggregateFnSum + 'ISNULL(CONVERT(float, MAX(' + @QIDColName + ')),0)'
				
				-- Add the next term onto @AggregateFnCount
				Set @AggregateFnCount = @AggregateFnCount + 'COUNT(' + @QIDColName + ')'

			End -- </d>

			-- Determine if this QuantitationID has any nonzero ER values or modified mass tags
			-- Note that QRLookupOptionalColumns leaves @ERValuesPresent, @ModsPresent, or @XTandemDataPresent at a non-zero
			--  value if they are non-zero when passed into the SP
			Exec QRLookupOptionalColumns @QuantitationID, 
					@ERValuesPresent = @ERValuesPresent OUTPUT, 
					@ModsPresent = @ModsPresent OUTPUT,
					@XTandemDataPresent = @XTandemDataPresent OUTPUT

			Set @MatchCount = @MatchCount + 1
			
		End -- </b>
	End -- </a>

	If @MatchCount > 0 And @SkipCrossTabSqlGeneration = 0
	Begin
		Set @AggregateFn = '(' + @AggregateFnSum + ') / (' + @AggregateFnCount + ') AS ' + @AggregateColName
		Set @CrossTabSqlGroupBy = @CrossTabSqlGroupBy + ', ' + @AggregateFn + ', ' + @AggregateFnCount + ' AS [Observation Count]'
	End

Done:
	Return @myError


GO
GRANT EXECUTE ON [dbo].[QRGenerateCrossTabSql] TO [DMS_SP_User]
GO
GRANT VIEW DEFINITION ON [dbo].[QRGenerateCrossTabSql] TO [MTS_DB_Dev]
GO
GRANT VIEW DEFINITION ON [dbo].[QRGenerateCrossTabSql] TO [MTS_DB_Lite]
GO

SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[QRGenerateCrossTabSql]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[QRGenerateCrossTabSql]
GO


CREATE Procedure dbo.QRGenerateCrossTabSql
/****************************************************	
**  Desc: Parses the values in @QuantitationIDList (separated by commas)
**		    to construct appropriate Sql for a crosstab query
**		  Also populates QuantitationIDListSql
**		  If @SeparateReplicateDataIDs = 1, then for QuantitationID's involving 
**          replicates, determines the most appropriate individual QuantitationID 
**          values for each of the replicates
**		  Lastly, populates @ERValuesPresent and @ModsPresent
**		    by calling QRLookupOptionalColumns
**
**  Return values:	@CrossTabSql and @QuantitationIDListSql are output parameters
**					Returns the number of Quantitation ID's found
**
**  Parameters: QuantitationID List to parse
**
**  Auth: mem
**	Date: 07/30/2003
**
**  Updated: 08/14/2003
**			 08/15/2003
**			 08/18/2003
**			 08/26/2003
**			 09/16/2003
**           12/13/2003 mem - Added logic to assure that @CrossTabSql and @CrossTabSqlGroupBy stay under 7000 and 8000 characters, respectively
**			 06/06/2004 mem - Now populating @ERValuesPresent, @DynamicModsPresent, and @StaticModsPresent
**			 07/01/2004 mem - Fixed bug during population of @QIDListUnique
**			 10/05/2004 mem - Updated for new MTDB schema
**			 05/24/2005 mem - Now checking for invalid QuantitationID values in @QuantitationIDList
**			 09/22/2005 mem - Added parameters @QuantitationIDListClean and updated to use QRCollapseToUniqueList
**
****************************************************/
(
	@QuantitationIDList varchar(1024),			-- Comma separated list of Quantitation ID's (duplicates are allowed)
	@SourceColName varchar(128),
	@AggregateColName varchar(128) = 'AbuAvg', 
	@AverageAcrossColumnsEnabled tinyint = 0,	-- If 1, then record Null when missing, otherwise record '''' when missing
	@SeparateReplicateDataIDs tinyint = 1,
	@CrossTabSql varchar(7000) = '' Output,
	@CrossTabSqlGroupBy varchar(8000) = '' Output,
	@QuantitationIDListSql varchar(1024) = '' Output,
	@ERValuesPresent tinyint=0 Output,
	@ModsPresent tinyint=0 Output,
	@QuantitationIDListClean varchar(1024)='' Output	-- Reduction of @QuantitationIDList into a unique list of numbers; additionally, is not affected by @SeparateReplicateDataIDs in that @QuantitationIDListClean will still contain replicate-based QIDs if present in @QuantitationIDList
)
AS
	Declare @CommaLoc int,
			@MDIDCommaLoc int,
			@MatchCount int,
			@ReplicateCount int

	Set @CommaLoc = 0
	Set @MDIDCommaLoc = 0
	Set @MatchCount = 0
	Set @ReplicateCount = 0
		
	Declare	@WorkingQIDList varchar(1024),
			@QIDListUnique varchar(1024),
			@QuantitationID varchar(19),
			@MaxQuantitationID varchar(19),
			@WorkingList varchar(4000),
			@MDIDList varchar(1024),
			@MDID varchar(19),
			@CorrespondingQIDList varchar(2048),
			@PotentialQIDValue varchar(19),
			@JobList varchar(2048),
			@JobListCount int,
			@QIDColName varchar(64),
			@AggregateFn varchar(7000),
			@AggregateFnSum varchar(6000),
			@AggregateFnCount varchar(6000)

	Declare @FractionHighestAbuToUse decimal(9,8),
			@NormalizeToStandardAbundances tinyint,
			@StandardAbundanceMin float,
			@StandardAbundanceMax float,
			@MaxCharLengthPerTerm int,								-- Number of characters added to @CrossTabSql for each term (estimate)
			@MaxCharLengthGroupByTerm int,
			@CrossTabSqlReachedMaxLength tinyint,
			@CrossTabSqlGroupByReachedMaxLength tinyint


	-- Assure that the following are blank
	Set @CrossTabSql = ''
	Set @CrossTabSqlGroupBy = ''
	Set @AggregateFnSum = ''
	Set @AggregateFnCount = ''
	Set @QuantitationIDListSql = ''
	Set @MaxQuantitationID = '1'
	
	-- Copy from @QuantationIDList into @WorkingQIDList and add a trailing comma (to make parsing easier)
	Set @WorkingQIDList = @QuantitationIDList + ','
	
	If @SeparateReplicateDataIDs <> 0
	Begin
		-- Examine T_Quantitation_MDIDs to determine the individual Quantitation_ID numbers 
		-- for the MDIDs defined for each  

		-- Copy from @WorkingQIDList into @WorkingList
		Set @WorkingList = @WorkingQIDList
	
		-- Clear @WorkingQIDList and @QuantitationIDListClean
		Set @WorkingQIDList = ''
		Set @QuantitationIDListClean = ''

		Set @CommaLoc = CharIndex(',', @WorkingList)
		WHILE @CommaLoc > 1
		BEGIN

			Set @QuantitationID = LTrim(Left(@WorkingList, @CommaLoc-1))
			Set @WorkingList = SubString(@WorkingList, @CommaLoc+1, Len(@WorkingList))
			
			If IsNumeric(@QuantitationID) = 1
			Begin
				-- This is a valid QID value; append to @QuantitationIDListClean
				Set @QuantitationIDListClean = @QuantitationIDListClean + @QuantitationID + ','
				
				-- Determine if this is actually a QuantitationID with replicates
				-- Do this using the following query, then checking @@RowCount
				-- Simultaneously, generate a comma delimited list of the MDIDs for this QuantitationID
				Set @MDIDList = ''
				SELECT @MDIDList = @MDIDList + Convert(varchar(19), MD_ID) + ','
				FROM T_Quantitation_MDIDs
				WHERE Quantitation_ID = @QuantitationID
				ORDER BY [Replicate]
				--
				Set @ReplicateCount = @@RowCount
			
				If @ReplicateCount > 0
				Begin
					If @ReplicateCount <= 1
						Set @CorrespondingQIDList = @QuantitationID + ','
					Else
						Begin

							Set @CorrespondingQIDList = ''

							-- Look up the settings used for this QuantitationID
							SELECT	@FractionHighestAbuToUse = Fraction_Highest_Abu_To_Use, 
									@NormalizeToStandardAbundances = Normalize_To_Standard_Abundances, 
									@StandardAbundanceMin = Standard_Abundance_Min, 
									@StandardAbundanceMax = Standard_Abundance_Max
							FROM T_Quantitation_Description
							WHERE Quantitation_ID = @QuantitationID
							
							-- Generate a comma delimited list of the most appropriate QuantitationID
							--  for each MDID in @MDIDList
							Set @MDIDCommaLoc = CharIndex(',', @MDIDList)
							While @MDIDCommaLoc > 1
							Begin
								Set @MDID = LTrim(Left(@MDIDList, @MDIDCommaLoc-1))
								Set @MDIDList = SubString(@MDIDList, @MDIDCommaLoc+1, Len(@MDIDList))
		
								If IsNumeric(@MDID) = 1
								Begin
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
									Begin
										Set @CorrespondingQIDList = @CorrespondingQIDList + @PotentialQIDValue + ','
										
										If Convert(int, @PotentialQIDValue) > Convert(int, @MaxQuantitationID)
											Set @MaxQuantitationID = @PotentialQIDValue
									End
								End

								Set @MDIDCommaLoc = CharIndex(',', @MDIDList)
							End

						End
					-- EndIf

					Set @WorkingQIDList = @WorkingQIDList + @CorrespondingQIDList
				End
			End

			Set @CommaLoc = CharIndex(',', @WorkingList)
		END		
	End

	-- Make sure no duplicates are present in @WorkingList
	Exec QRCollapseToUniqueList @WorkingQIDList, @QIDListUnique OUTPUT
	
	-- Make sure @QIDListUnique is not zero-length
	If Len(IsNull(@QIDListUnique, '')) = 0
		Set @QIDListUnique = '0,'
	
	-- Make sure @QIDListUnique ends in a comma
	If SubString(@QIDListUnique, Len(@QIDListUnique), 1) <> ','
		Set @QIDListUnique = @QIDListUnique + ','

	-- Make sure no duplicates are presesnt in @QuantitationIDListClean
	Exec QRCollapseToUniqueList @QuantitationIDListClean, @QuantitationIDListClean OUTPUT
		
	-- Compute @MaxCharLengthPerTerm
	-- Do this by composing the default CrossTabSql term, using @MaxQuantitationID, then finding its length
	Set @QuantitationID = @MaxQuantitationID
	Set @QIDColName = '[Jobs 12345, 12346, 12347, 12348, 12349, 12350 (QID' + @QuantitationID + ')]'
	Set @CrossTabSql = @CrossTabSql + ' MAX(CASE WHEN Quantitation_ID=' + @QuantitationID
	Set @CrossTabSql = @CrossTabSql + ' THEN convert(varchar(19), ' + @SourceColName + ')'
	Set @CrossTabSql = @CrossTabSql + ' ELSE'
	If @AverageAcrossColumnsEnabled = 1
		Set @CrossTabSql = @CrossTabSql + ' NULL'
	Else
		Set @CrossTabSql = @CrossTabSql + ' '''''
	Set @CrossTabSql = @CrossTabSql + ' END) AS ' + @QIDColName
	Set @MaxCharLengthPerTerm = Len(@CrossTabSql)
	Set @CrossTabSqlReachedMaxLength = 0

	-- Compute @MaxCharLengthGroupBy
	Set @CrossTabSqlGroupBy = ',ISNULL(MAX(' + @QIDColName + '),'''') AS ' + @QIDColName
	Set @AggregateFnSum = '+ISNULL(CONVERT(float, MAX(' + @QIDColName + ')),0)'
	Set @AggregateFnCount = '+COUNT(' + @QIDColName + ')'
	Set @AggregateFn = '(' + @AggregateFnSum + ') / (' + @AggregateFnCount + ') AS ' + @AggregateColName
	Set @CrossTabSqlGroupBy = @CrossTabSqlGroupBy + ', ' + @AggregateFn

	Set @MaxCharLengthGroupByTerm = Len(@CrossTabSqlGroupBy)
	Set @CrossTabSqlGroupByReachedMaxLength = 0
	
	-- Assure that the following are blank (must be re-blanked since we used these to determine maximum lengths)
	Set @CrossTabSql = ''
	Set @CrossTabSqlGroupBy = ''
	Set @AggregateFnSum = ''
	Set @AggregateFnCount = ''

	-- Construct CrossTabSql
	-- Copy from @WorkingQIDList into @WorkingList
	Set @WorkingList = @QidListUnique
	Set @CommaLoc = CharIndex(',', @WorkingList)
	WHILE @CommaLoc > 1
	BEGIN

		Set @QuantitationID = LTrim(Left(@WorkingList, @CommaLoc-1))
		Set @WorkingList = SubString(@WorkingList, @CommaLoc+1, Len(@WorkingList))
		
		-- See if @CrossTabSql has gotten too long
		If Len(@CrossTabSql) + @MaxCharLengthPerTerm > 6990
			Set @CrossTabSqlReachedMaxLength = 1
			
		-- Continue if QuantitationID is numeric
		If IsNumeric(@QuantitationID) = 1 And @CrossTabSqlReachedMaxLength = 0
		Begin
			If Len(@CrossTabSql) > 0
			Begin
				Set @CrossTabSql = @CrossTabSql + ','
				Set @QuantitationIDListSql = @QuantitationIDListSql + ','
			End
		
			-- Lookup the job numbers that this QuantitationID corresponds to
			Set @JobList = ''
			
			SELECT	@JobList = @JobList + ',' + LTrim(RTrim(Convert(varchar(19), T_Match_Making_Description.MD_Reference_Job)))
			FROM	T_Quantitation_Description INNER JOIN
					T_Quantitation_MDIDs ON 
					T_Quantitation_Description.Quantitation_ID = T_Quantitation_MDIDs.Quantitation_ID
					  INNER JOIN
					T_Match_Making_Description ON 
					T_Quantitation_MDIDs.MD_ID = T_Match_Making_Description.MD_ID
			WHERE	T_Quantitation_Description.Quantitation_ID = Convert(int, @QuantitationID)
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
					-- Just one jobs
					Set @JobList = 'Job ' + @JobList
				Else
					-- Multiple jobs
					Set @JobList = 'Jobs ' + @JobList
			  End
			
			-- Make sure @JobList isn't too long
			If Len(@JobList) > 45
				Set @JobList = SubString(@JobList, 1, 42) + '...'
			
			-- Define @QIDColName, surrounding with brackets, and appending a space
			Set @QIDColName = '[' + @JobList + ' (QID' + @QuantitationID + ')]'
			
			-- Add the next term onto @CrossTabSql
			Set @CrossTabSql = @CrossTabSql + 'MAX(CASE WHEN Quantitation_ID=' + @QuantitationID 
			Set @CrossTabSql = @CrossTabSql + ' THEN convert(varchar(19), ' + @sourceColName + ')'
			Set @CrossTabSql = @CrossTabSql + ' ELSE'
			If @AverageAcrossColumnsEnabled = 1
				Set @CrossTabSql = @CrossTabSql + ' NULL'
			Else
				Set @CrossTabSql = @CrossTabSql + ' '''''
			Set @CrossTabSql = @CrossTabSql + ' END) AS ' + @QIDColName
			Set @QuantitationIDListSql = @QuantitationIDListSql + @QuantitationID


			Set @AggregateFn = '(' + @AggregateFnSum + ') / (' + @AggregateFnCount + ') AS ' + @AggregateColName
			
			-- See if @CrossTabSqlGroupBy has gotten too long
			If Len(@CrossTabSqlGroupBy + ', ' + @AggregateFn) + @MaxCharLengthGroupByTerm > 7990
				Set @CrossTabSqlGroupByReachedMaxLength = 1
				
			If @CrossTabSqlGroupByReachedMaxLength = 0
			 Begin
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

			  End
			 
			  
			 Set @MatchCount = @MatchCount + 1
		End

		Set @CommaLoc = CharIndex(',', @WorkingList)
	END

	If @MatchCount > 0
	Begin
		-- If @CrossTabSqlGroupBy and @CrossTabSql reached the maximum length, then cannot compute the aggregate
		-- value since we run the risk of a divide by zero error
		If @CrossTabSqlGroupByReachedMaxLength = 0 And @CrossTabSqlReachedMaxLength = 0
			Set @AggregateFn = '(' + @AggregateFnSum + ') / (' + @AggregateFnCount + ') AS ' + @AggregateColName
		Else
			Set @AggregateFn = '0 AS ' + @AggregateColName
			
		Set @CrossTabSqlGroupBy = @CrossTabSqlGroupBy + ', ' + @AggregateFn
	End

	-- Determine if any of the Quantitation ID's in @QidListUnique have any ER values or modifications
	Set @WorkingList = @QidListUnique
	Set @CommaLoc = CharIndex(',', @WorkingList)
	WHILE @CommaLoc > 1
	BEGIN

		Set @QuantitationID = LTrim(Left(@WorkingList, @CommaLoc-1))
		Set @WorkingList = SubString(@WorkingList, @CommaLoc+1, Len(@WorkingList))

		If IsNumeric(@QuantitationID) = 1
			-- Determine if this QuantitationID has any nonzero ER values or modified mass tags
			Exec QRLookupOptionalColumns @QuantitationID, 
					@ERValuesPresent = @ERValuesPresent OUTPUT, 
					@ModsPresent = @ModsPresent OUTPUT

		Set @CommaLoc = CharIndex(',', @WorkingList)
	END

	Return @MatchCount


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[QRGenerateCrossTabSql]  TO [DMS_SP_User]
GO


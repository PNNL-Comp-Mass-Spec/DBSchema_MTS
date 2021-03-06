/****** Object:  StoredProcedure [dbo].[ValidateNewAnalysesUsingProteinCollectionFilters] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.ValidateNewAnalysesUsingProteinCollectionFilters
/****************************************************
**
**	Desc:
**		Compares the Protein_Collection_List and Protein_Options_List
**		 values in table #TmpNewAnalysisJobs against the
**		 protein collection filters defined in T_Process_Config
**		Updates jobs that do pass the filters to have Valid = 1
**
**		Note that the calling procedure must create and populate table #TmpNewAnalysisJobs
**		The calling procedure must also have already created tables #TmpFilterList and #PreviewSqlData
**
**		Note also that jobs with Valid = 1 are not examined
**
**	Return values: 0: success, otherwise, error code
**
**	Auth:	mem
**	Date:	06/10/2006
**			10/07/2007 mem - Increased size of @ProteinCollectionList to varchar(max)
**			11/05/2007 mem - Updated to allow use all analysis jobs if T_Process_Config doesn't have any entries for Protein_Collection_Filter or Protein_Collection_and_Protein_Options_Combo
**			04/08/2013 mem - Now using CROSS APPLY to create lists of protein collections and protein options for each job (removing the need for a while loop)
**    
*****************************************************/
(
	@PreviewSql tinyint,
	@message varchar(255) output
)
As
	set nocount on

	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	Declare @MatchCount int
	Declare @FilterMatchCount int

	Declare @NewAnalysisJobsLookupTableName varchar(256)
	Declare @SAddnl varchar(256)
	
	Declare @ProteinCollectionFilterDefined tinyint
	Set @ProteinCollectionFilterDefined = 0
	
	---------------------------------------------------
	-- See if #TmpNewAnalysisJobs contains any jobs that still have Valid = 0
	---------------------------------------------------
	Set @MatchCount = 0
	SELECT @MatchCount = COUNT(*)
	FROM #TmpNewAnalysisJobs
	WHERE Valid = 0
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @MatchCount > 0
	Begin -- <b1>
		---------------------------------------------------
		-- Count number of Protein_Collection_and_Protein_Options_Combo
		-- entries in T_Process_Config
		---------------------------------------------------
		--					
		Set @MatchCount = 0
		SELECT @MatchCount = COUNT(*)
		FROM T_Process_Config
		WHERE [Name] = 'Protein_Collection_and_Protein_Options_Combo'
		
		If @MatchCount > 0
		Begin -- <c1>

			Set @ProteinCollectionFilterDefined = 1

			CREATE TABLE #TmpJobsMatchingProteinCollectionCriteria (
				Job int
			)


			---------------------------------------------------
			-- Define the lookup table name
			---------------------------------------------------
			Set @NewAnalysisJobsLookupTableName = '#TmpNewAnalysisJobs'
			Set @SAddnl = 'Valid = 0'
			
			---------------------------------------------------
			-- Populate #TmpJobsMatchingProteinCollectionCriteria using jobs that match
			-- the Protein_Collection_and_Protein_Options_Combo entries in T_Process_Config
			---------------------------------------------------

			set @FilterMatchCount = 0
			Exec @myError = ParseFilterListDualKey 'Protein_Collection_and_Protein_Options_Combo', @NewAnalysisJobsLookupTableName, 'Protein_Collection_List', 'Protein_Options_List', 'Job', @SAddnl, @FilterMatchCount OUTPUT, @Delimiter=';'
			--
			If @myError <> 0
			Begin
				set @message = 'Error looking up matching jobs using the Protein_Collection_and_Protein_Options_Combo filters'
				set @myError = 40002
				goto Done
			End
			Else
			Begin -- <d0>
				INSERT INTO #TmpJobsMatchingProteinCollectionCriteria (Job)
				SELECT Convert(int, Value) FROM #TmpFilterList
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				
				UPDATE #TmpNewAnalysisJobs
				SET Valid = 1
				FROM #TmpNewAnalysisJobs NAJ INNER JOIN
						#TmpJobsMatchingProteinCollectionCriteria JMPCC ON NAJ.Job = JMPCC.Job
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				
				If @PreviewSql <> 0
					INSERT INTO #PreviewSqlData (Filter_Type, Value)
					SELECT 'Jobs matching Protein_Collection_and_Protein_Options filter', Convert(varchar(18), Job)
					FROM #TmpJobsMatchingProteinCollectionCriteria

			End -- </d0>
		End -- </c1>
	End -- </b1>
	
	---------------------------------------------------
	-- See if #TmpNewAnalysisJobs contains any jobs that still have Valid = 0
	---------------------------------------------------
	Set @MatchCount = 0
	SELECT @MatchCount = COUNT(*)
	FROM #TmpNewAnalysisJobs
	WHERE Valid = 0
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @MatchCount > 0
	Begin -- <b2>
		---------------------------------------------------
		-- Count the number of Protein_Collection_Filter or Seq_Direction_Filter
		-- entries in T_Process_Config
		---------------------------------------------------
		--
		Set @MatchCount = 0
		SELECT @MatchCount = COUNT(*)
		FROM T_Process_Config
		WHERE [Name] IN ('Protein_Collection_Filter', 'Seq_Direction_Filter')
		--
		If @MatchCount > 0
		Begin -- <c2>
			---------------------------------------------------
			-- Validate the values for Protein_Collection_Filter and Seq_Direction_Filter in fields 
			--  Protein_Collectionst_List and Protein_Options_List in #TmpNewAnalysisJobs
			---------------------------------------------------

			---------------------------------------------------
			-- Populate table #TmpNewAnalysisJobProteinCollectionNames with the info in #TmpNewAnalysisJobs and then 
			--  compare the collection names to the filters defined in T_Process_Config
			--
			-- In addition, populate table #TmpNewAnalysisJobProteinOptions with the info in #TmpNewAnalysisJobs and then 
			--  compare the Protein_Option Keywords and Values vs. the filters defined in T_Process_Config
			---------------------------------------------------
			
			-- Create the table that will hold the protein collection names defined for each job		
			CREATE TABLE #TmpNewAnalysisJobProteinCollectionNames (
				[Job] int NOT NULL ,
				[ProteinCollection] varchar(256) NOT NULL,
				[Valid] tinyint NOT NULL DEFAULT (0)
			)	

			-- Create the table that will hold the Keywords and Values for the protein options defined for each job		
			CREATE TABLE #TmpNewAnalysisJobProteinOptions (
				[Job] int NOT NULL ,
				[Keyword] varchar(256) NOT NULL,
				[Value] varchar(256) NOT NULL,
				[Valid] tinyint NOT NULL DEFAULT (0)
			)	


			-- Parse out the protein collections for each job
			--
			INSERT INTO #TmpNewAnalysisJobProteinCollectionNames (Job, ProteinCollection)
			SELECT Job, PCL.Value
			FROM #TmpNewAnalysisJobs CROSS APPLY dbo.udfParseDelimitedList(Protein_Collection_List, ',') as PCL
			WHERE Valid = 0
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error

			
			-- Parse out the protein options for each job
			--
			INSERT INTO #TmpNewAnalysisJobProteinOptions (Job, Keyword, Value)
			SELECT Job, PCO.Keyword, PCO.Value
			FROM #TmpNewAnalysisJobs CROSS APPLY dbo.udfParseKeyValueList(Protein_Options_List, ',', '=') as PCO
			WHERE Valid = 0
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error


			---------------------------------------------------
			-- Count number of Protein_Collection_Filter
			-- entries in T_Process_Config
			---------------------------------------------------
			--
			Set @MatchCount = 0
			SELECT @MatchCount = COUNT(*)
			FROM T_Process_Config
			WHERE [Name] = 'Protein_Collection_Filter'
			--
			If @MatchCount > 0
			Begin -- <d2>
			
				Set @ProteinCollectionFilterDefined = 1
				
				---------------------------------------------------
				-- Validate the protein collection names
				---------------------------------------------------
				--
				-- Mark jobs in #TmpNewAnalysisJobProteinCollectionNames as valid if they contain 
				--  protein collection names that match those defined in T_Process_Config
				UPDATE #TmpNewAnalysisJobProteinCollectionNames
				SET Valid = 1
				WHERE ProteinCollection IN 
						(	SELECT [Value] 
							FROM T_Process_Config 
							WHERE [Name] = 'Protein_Collection_Filter')
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error

				-- Delete jobs from #TmpNewAnalysisJobs that are defined in #TmpNewAnalysisJobProteinCollectionNames
				--  but do not have any valid collection names
				DELETE #TmpNewAnalysisJobs
				FROM #TmpNewAnalysisJobs NAJ INNER JOIN 
					(	SELECT Job
						FROM #TmpNewAnalysisJobProteinCollectionNames
						GROUP BY Job
						HAVING MAX(Valid) = 0
					) JobsToDelete ON NAJ.Job = JobsToDelete.Job
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error
				
			End -- </d2>

			---------------------------------------------------
			-- Count number of Seq_Direction_Filter
			-- entries in T_Process_Config
			---------------------------------------------------
			--
			Set @MatchCount = 0
			SELECT @MatchCount = COUNT(*)
			FROM T_Process_Config
			WHERE [Name] IN ('Seq_Direction_Filter')
			--
			If @MatchCount > 0
			Begin -- <d3>
			
				---------------------------------------------------
				-- Validate the protein option values; currently only checks seq_direction,
				--  but could add other checks in the future
				---------------------------------------------------
				--
				-- Mark jobs in #TmpNewAnalysisJobProteinOptions as valid if they contain 'seq_direction' values
				--  that match those defined in T_Process_Config
				UPDATE #TmpNewAnalysisJobProteinOptions
				SET Valid = 1
				WHERE Keyword = 'seq_direction' AND 
					Value IN (SELECT [Value] FROM T_Process_Config WHERE [Name] = 'Seq_Direction_Filter')
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error

				-- Delete entries from #TmpNewAnalysisJobProteinOptions that have 
				-- unknown keywords or keywords that we do not filter on
				DELETE FROM #TmpNewAnalysisJobProteinOptions
				WHERE NOT Keyword IN ('seq_direction')
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error

				-- Delete jobs from #TmpNewAnalysisJobs that have non-valid entries in #TmpNewAnalysisJobProteinOptions
				DELETE #TmpNewAnalysisJobs
				FROM #TmpNewAnalysisJobs NAJ INNER JOIN
					#TmpNewAnalysisJobProteinOptions NAJPO ON NAJ.Job = NAJPO.Job
				WHERE NAJPO.Valid = 0
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error
				
			End -- </d3>

			---------------------------------------------------
			-- Since T_Process_Config contained Protein_Collection_Filter or Seq_Direction_Filter,
			--  update Valid to 1 for any jobs in #TmpNewAnalysisJobs that still have Valid = 0,
			--  since these jobs were not deleted by section d2 or d3 above
			---------------------------------------------------
			UPDATE #TmpNewAnalysisJobs
			SET Valid = 1
			WHERE Valid = 0
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error

		End -- </c2>

		If @ProteinCollectionFilterDefined = 0
		Begin
			-- T_Process_Config doesn't have any entries for Protein_Collection_Filter or Protein_Collection_and_Protein_Options_Combo
			-- Thus, mark all remaining jobs as valid
			UPDATE #TmpNewAnalysisJobs
			SET Valid = 1
			WHERE Valid = 0
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
		End

	End -- </b2>		
	
	---------------------------------------------------
	-- Delete any jobs in #TmpNewAnalysisJobs that still have Valid = 0
	---------------------------------------------------
	DELETE #TmpNewAnalysisJobs
	WHERE Valid = 0
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error

Done:
	Return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[ValidateNewAnalysesUsingProteinCollectionFilters] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[ValidateNewAnalysesUsingProteinCollectionFilters] TO [MTS_DB_Lite] AS [dbo]
GO

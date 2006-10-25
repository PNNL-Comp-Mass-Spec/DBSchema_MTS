/****** Object:  StoredProcedure [dbo].[ParseFilterListDualKey] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.ParseFilterListDualKey
/****************************************************
**
**	Desc: Looks for entries in column Name in T_Process_Config having Value = @filterValue
**		  For each entry, looks in columns @filterValueLookupColumn1Name and 
**        @filterValueLookupColumn2Name in table @filterValueLookupTableName for matching entries
**		  Populates temporary table #TmpFilterList with the matching rows, pulling the data from column @targetValueColumnName
**		  Note that the calling SP needs to create the #TmpFilterList table
**
**	Return values: 0: success, otherwise, error code
**
**	Auth:	mem
**	Date:	04/6/2005
**			11/30/2005 mem - Now using udfTrimToCRLF() to assure that values in T_Process_Config are truncated at the first CR or LF value
**			06/08/2005 mem - Added parameter @Delimiter
**			09/25/2006 mem - Now including ORDER BY Process_Config_ID in the SELECT TOP 1 query to ensure that all entries are processed
**    
*****************************************************/
(
	@filterValue varchar(128) = 'Campaign_and_Experiment',
	@filterValueLookupTableName varchar(256) = 'MT_Main.dbo.V_DMS_Analysis_Job_Import',
	@filterValueLookupColumn1Name varchar(128) = 'Campaign',		-- Look for data in this column, and
	@filterValueLookupColumn2Name varchar(128) = 'Experiment',		-- Look for data in this column
	@targetValueColumnName varchar(128) = 'Job',					-- Store values from this column
	@filterLookupAddnlWhereClause varchar(2000) = '',			-- Can be used to filter on additional fields in @filterValueLookupTableName; for example, "Campaign Like 'Deinococcus' AND  InstrumentClass = 'Finnigan_FTICR'"
	@filterMatchCount int = 0 OUTPUT,
	@Delimiter varchar(2) = ','
)
As
	set nocount on

	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	declare @loopContinue tinyint
	declare @ProcessConfigID int
	declare @result int

	declare @DelimiterLoc int
	declare @ComparisonOperator1 varchar(8)
	declare @ComparisonOperator2 varchar(8)
	
	declare @Key1Value varchar(150)
	declare @Key2Value varchar(150)

	declare @ValueMatchStr varchar(250)

	declare @S nvarchar(4000)


	TRUNCATE TABLE #TmpFilterList
	

	---------------------------------------------------
	-- See if any rows are present in T_Process_Config matching @filterValue
	---------------------------------------------------

	Set @filterMatchCount = 0
	
	SELECT @filterMatchCount = COUNT(*)
	FROM T_Process_Config
	WHERE [Name] = @filterValue AND Len(Value) > 0
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0 OR @myRowCount = 0
	begin
		set @myError = 60001
		goto Done
	end


	If @filterMatchCount > 0
	Begin -- <a>
	
		---------------------------------------------------
		-- Loop through the rows in T_Process_Config matching @filterValue
		-- Only process the rows containing @Delimiter, which is required for dual key entries
		---------------------------------------------------
				
		Set @loopContinue = 1
		Set @ProcessConfigID = 0

		While @loopContinue = 1 And @myError = 0
		Begin -- <b>
			SELECT TOP 1 @ValueMatchStr = dbo.udfTrimToCRLF(Value),
						 @ProcessConfigID = Process_Config_ID
			FROM T_Process_Config
			WHERE [Name] = @filterValue AND
				Value Like '%' + @Delimiter + '%' AND 
				Process_Config_ID > @ProcessConfigID
			ORDER BY Process_Config_ID
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount

			IF @myRowcount <> 1
				Set @loopContinue = 0
			Else
			Begin -- <c>
				
				-- Split @ValueMatchStr at the @Delimiter
				Set @DelimiterLoc = CharIndex(@Delimiter, @ValueMatchStr)
				
				Set @Key1Value = LTrim(RTrim(SubString(@ValueMatchStr, 1, @DelimiterLoc-1)))
				Set @Key2Value = LTrim(RTrim(SubString(@ValueMatchStr, @DelimiterLoc+1, Len(@ValueMatchStr) - @DelimiterLoc)))

				-- If the Key string contains a percent sign, then use LIKE, otherwise use equals
				If @Key1Value Like '%[%]%'
					Set @ComparisonOperator1 = ' LIKE '
				Else
					Set @ComparisonOperator1 = ' = '
		
				-- If the Key string contains a percent sign, then use LIKE, otherwise use equals
				If @Key2Value Like '%[%]%'
					Set @ComparisonOperator2 = ' LIKE '
				Else
					Set @ComparisonOperator2 = ' = '
					
				Set @S = ''
				Set @S = @S + ' INSERT INTO #TmpFilterList (Value)'
				Set @S = @S + ' SELECT DISTINCT PT.' + @targetValueColumnName
				Set @S = @S + ' FROM '
				Set @S = @S +   @filterValueLookupTableName + ' AS PT'
				Set @S = @S + ' LEFT OUTER JOIN #TmpFilterList ON PT.' + @targetValueColumnName + ' = #TmpFilterList.Value'
				Set @S = @S + ' WHERE PT.' + @filterValueLookupColumn1Name + @ComparisonOperator1 + '''' + @Key1Value + ''' AND'
				Set @S = @S +       ' PT.' + @filterValueLookupColumn2Name + @ComparisonOperator2 + '''' + @Key2Value + ''' AND'
				Set @S = @S +      ' #TmpFilterList.Value IS NULL'
				If Len(@filterLookupAddnlWhereClause) > 0
					Set @S = @S + ' AND ' + @filterLookupAddnlWhereClause

				exec @result = sp_executesql @S
				--
				select @myError = @result, @myRowcount = @@rowcount
				--
				if @myError  <> 0
				begin
					set @myError = 60003
					goto Done
				end
			End -- </c>
		End -- </b>
	End -- </a>
	
Done:
	Return @myError


GO

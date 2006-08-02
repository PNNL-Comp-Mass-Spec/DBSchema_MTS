SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[ParseFilterList]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[ParseFilterList]
GO


CREATE PROCEDURE dbo.ParseFilterList
/****************************************************
**
**	Desc: Looks for entries in column Name in T_Process_Config having Value = @filterValue
**		  For each entry, looks in column @filterValueLookupColumnName in
**		    table @filterValueLookupTableName for matching entries
**		  Populates temporary table #TmpFilterList with the matching rows
**		  Note that the calling SP needs to create the #TmpFilterList table
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters: 
**
**
**	Auth:	mem
**	Date:	10/01/2004
**			11/30/2005 mem - Now using udfTrimToCRLF() to assure that values in T_Process_Config are truncated at the first CR or LF value
**			02/23/2006 mem - Expanded @ValueMatchStr to varchar(128)
**    
*****************************************************/
(
	@filterValue varchar(128) = 'Experiment',
	@filterValueLookupTableName varchar(256) = 'PT_Software_Q49..T_Analysis_Description',
	@filterValueLookupColumnName varchar(128) = 'Experiment',
	@filterLookupAddnlWhereClause varchar(2000) = '',			-- Can be used to filter on additional fields in @filterValueLookupTableName; for example, "Campaign Like 'Deinococcus' AND  InstrumentClass = 'Finnigan_FTICR'"
	@filterMatchCount int = 0 OUTPUT
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

	declare @ValueMatchStr varchar(128)

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
		-- Populate #TmpFilterList with a list of matching items
		---------------------------------------------------

		-- Append items that do not contain a percent sign
		--
		INSERT INTO #TmpFilterList (Value)
		SELECT dbo.udfTrimToCRLF(Value)
		FROM T_Process_Config
		WHERE [Name] = @filterValue AND
			Value Not Like '%[%]%' AND 
			Len(Value) > 0
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError  <> 0
		begin
			set @myError = 60002
			goto Done
		end

		-- Process items that do contain a percent sign
		Set @loopContinue = 1
		Set @ProcessConfigID = 0

		While @loopContinue = 1 And @myError = 0
		Begin -- <b>
			SELECT TOP 1 @ValueMatchStr = dbo.udfTrimToCRLF(Value),
						 @ProcessConfigID = Process_Config_ID
			FROM T_Process_Config
			WHERE [Name] = @filterValue AND
				Value Like '%[%]%' AND 
				Process_Config_ID > @ProcessConfigID AND 
				Len(Value) > 0
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount

			IF @myRowcount <> 1
				Set @loopContinue = 0
			Else
			Begin -- <c>
				Set @S = ''
				Set @S = @S + ' INSERT INTO #TmpFilterList (Value)'
				Set @S = @S + ' SELECT DISTINCT PT.' + @filterValueLookupColumnName
				Set @S = @S + ' FROM '
				Set @S = @S +   @filterValueLookupTableName + ' AS PT'
				Set @S = @S + ' LEFT OUTER JOIN #TmpFilterList ON PT.' + @filterValueLookupColumnName + ' = #TmpFilterList.Value'
				Set @S = @S + ' WHERE PT.' + @filterValueLookupColumnName + ' LIKE ''' + @ValueMatchStr + ''' AND'
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
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


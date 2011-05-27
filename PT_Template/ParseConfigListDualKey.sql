/****** Object:  StoredProcedure [dbo].[ParseConfigListDualKey] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.ParseConfigListDualKey
/****************************************************
**
**	Desc: Looks for entries in column T_Process_Config where Name = @ConfigName
**		  Extracts the data for each entry, splitting on delimiter @Delimiter
**		  Populates temporary table #TmpConfigDefs with the configuration data
**		  Note that the calling SP needs to create the #TmpConfigDefs table
**
**		CREATE TABLE #TmpConfigDefs (
**			Value1 varchar(512) NOT NULL,
**			Value2 varchar(512) NOT NULL
**		)
**
**	Return values: 0: success, otherwise, error code
**
**	Auth:	mem
**	Date:	10/12/2010 mem - Initial Version
**    
*****************************************************/
(
	@ConfigName varchar(128) = 'NET_Regression_Param_File_Name_by_Sample_Label',
	@MatchCount int = 0 OUTPUT,
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
	
	declare @Key1Value varchar(800)
	declare @Key2Value varchar(800)

	declare @ValueMatchStr varchar(800)

	declare @S nvarchar(4000)


	TRUNCATE TABLE #TmpConfigDefs
	
	---------------------------------------------------
	-- See if any rows are present in T_Process_Config matching @ConfigName
	---------------------------------------------------

	Set @MatchCount = 0
	
	SELECT @MatchCount = COUNT(*)
	FROM T_Process_Config
	WHERE [Name] = @ConfigName AND Len(Value) > 0
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0 OR @myRowCount = 0
	begin
		set @myError = 60001
		goto Done
	end


	If @MatchCount > 0
	Begin -- <a>
	
		---------------------------------------------------
		-- Loop through the rows in T_Process_Config matching @ConfigName
		-- Only process the rows containing @Delimiter, which is required for dual key entries
		---------------------------------------------------
				
		Set @loopContinue = 1
		Set @ProcessConfigID = 0

		While @loopContinue = 1 And @myError = 0
		Begin -- <b>
			SELECT TOP 1 @ValueMatchStr = dbo.udfTrimToCRLF(Value),
						 @ProcessConfigID = Process_Config_ID
			FROM T_Process_Config
			WHERE [Name] = @ConfigName AND
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

				INSERT INTO #TmpConfigDefs (Value1, Value2)
				VALUES (@Key1Value, @Key2Value)
				--
				select @myError = @@error, @myRowcount = @@rowcount
				
			End -- </c>
		End -- </b>
	End -- </a>
	
Done:
	Return @myError


GO

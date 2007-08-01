/****** Object:  StoredProcedure [dbo].[ResetIdentityFieldSeed] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.ResetIdentityFieldSeed
/****************************************************
**
**	Desc:	Resets the identity field seed in the various
**			data tables to the maximum value (or to the
**			original identity value if the table is empty)
**
**	Return values: 0: success, otherwise, error code
**
**
**	Auth:	mem
**	Date:	05/23/2007 mem - Ported to Master_Sequences DB
**
*****************************************************/
(
	@InfoOnly tinyint = 0,
	@message varchar(255) = ''
)
AS

	Set NoCount On

	Declare @myRowCount int
	Declare @myError int
	Set @myRowCount = 0
	Set @myError = 0

	Declare @TableName varchar(100)
	Declare @FieldName varchar(100)
	
	Declare @Sql nvarchar(2048)
	Declare @ParamDef nvarchar(1024)

	Declare @IdentitySeed int
	Declare @CurrentIdentity int
	Declare @MaxValue int
	Declare @RowCount int
	
	Declare @Continue int
	Declare @result int
	Declare @SeedToUse int
	Declare @IdentityUpdated tinyint
	
	Set @message = ''
	
	/*
	** Use the following to find all tables in this DB that have identity columns
	**
		SELECT TABLE_NAME, IDENT_CURRENT(TABLE_NAME) AS IDENT_CURRENT
		FROM INFORMATION_SCHEMA.TABLES
		WHERE IDENT_SEED(TABLE_NAME) IS NOT NULL
	**
	*/

	--------------------------------------------------------------
	-- Create a temporary table to hold table info and stats
	--------------------------------------------------------------
	--
	CREATE TABLE #Tmp_TablesToUpdate (
		Table_Name varchar(100) NOT NULL,
		Field_Name varchar(75) NOT NULL,
		Processed tinyint NOT NULL DEFAULT 0,
		Identity_Updated tinyint NOT NULL DEFAULT 0,
		Identity_Seed int NULL,
		Current_Identity int NULL,
		Max_Value int NULL,
		Row_Count int NULL
	)
	
	CREATE UNIQUE INDEX #IX_Tmp_TablesToUpdate ON #Tmp_TablesToUpdate (Table_Name ASC)

	--------------------------------------------------------------
	-- Define the tables to update
	--------------------------------------------------------------
	--
	INSERT INTO #Tmp_TablesToUpdate (Table_Name, Field_Name) VALUES ('T_Log_Entries',				'Entry_ID')
	INSERT INTO #Tmp_TablesToUpdate (Table_Name, Field_Name) VALUES ('T_Stats_History',				'Entry_ID')
	INSERT INTO #Tmp_TablesToUpdate (Table_Name, Field_Name) VALUES ('T_Candidate_Seq_Processing_History',			'Entry_ID')

	--------------------------------------------------------------
	-- The following is used in the call to sp_executesql
	--------------------------------------------------------------
	--
	set @ParamDef = '@IdentitySeed int output, @CurrentIdentity int output, @MaxValue int output, @RowCount int output'	

	--------------------------------------------------------------
	-- Loop through the entries in #Tmp_TablesToUpdate
	--------------------------------------------------------------
	--
	Set @Continue = 1
	Set @myError = 0
	While @Continue = 1 And @myError = 0
	Begin
		--------------------------------------------------------------
		-- Lookup the next table to process
		--------------------------------------------------------------
		--
		SELECT TOP 1 @TableName = Table_Name, @FieldName = Field_Name
		FROM #Tmp_TablesToUpdate
		WHERE Processed = 0
		ORDER BY Table_Name
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		
		If @myRowCount < 1
			Set @Continue = 0
		Else
		Begin
			--------------------------------------------------------------
			-- Lookup the current identity stats, maximum value, and number of rows
			--------------------------------------------------------------
			--
			Set @IdentitySeed = 0
			Set @CurrentIdentity = 0
			Set @MaxValue = 0
			Set @RowCount = 0
			
			Set @Sql = ''
			Set @Sql = @Sql + ' SELECT @IdentitySeed = IDENT_SEED(''' + @TableName + '''),'
			Set @Sql = @Sql +        ' @CurrentIdentity = IDENT_CURRENT(''' + @TableName + '''),'
			Set @Sql = @Sql +        ' @MaxValue = IsNull(Max(' + @FieldName + '),0),'
			Set @Sql = @Sql +        ' @RowCount = COUNT(*)'
			Set @Sql = @Sql + ' FROM ' + @TableName
			
			exec @result = sp_executesql @Sql, @ParamDef, @IdentitySeed = @IdentitySeed output, 
														  @CurrentIdentity = @CurrentIdentity output, 
														  @MaxValue = @MaxValue output,
														  @RowCount = @RowCount output
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			
			--------------------------------------------------------------
			-- Possibly update the identity
			--------------------------------------------------------------
			--
			Set @IdentityUpdated = 0
			--
			If @result = 0 AND @myError = 0 AND @InfoOnly = 0
			Begin
				If @RowCount = 0 OR @CurrentIdentity > @MaxValue AND @CurrentIdentity > @IdentitySeed
				Begin
					If @RowCount = 0
						Set @SeedToUse = @IdentitySeed-1
					Else
					Begin
						If @MaxValue < @IdentitySeed
							Set @SeedToUse = @IdentitySeed-1
						Else
							Set @SeedToUse = @MaxValue
					End
					DBCC CHECKIDENT (@TableName, RESEED, @SeedToUse) 
					Set @IdentityUpdated = 1
				End
			End
				

			UPDATE #Tmp_TablesToUpdate
			SET Identity_Seed = @IdentitySeed,
				Current_Identity = @CurrentIdentity,
				Max_Value = @MaxValue,
				Row_Count = @RowCount,
				Processed = 1,
				Identity_Updated = @IdentityUpdated
			WHERE Table_Name = @TableName
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error

		End
	End

	SELECT	Table_Name, Field_Name,
			Identity_Updated, Identity_Seed,
			Current_Identity, Max_Value,
			CASE WHEN Row_Count > 0 
			THEN Current_Identity - Max_Value
			ELSE 0
			END AS Difference
	FROM #Tmp_TablesToUpdate
	ORDER BY Table_Name
		
Done:
	Return @myError


GO

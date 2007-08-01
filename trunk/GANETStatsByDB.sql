/****** Object:  StoredProcedure [dbo].[GANETStatsByDB] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.GANETStatsByDB
/****************************************************
**
**	Desc: 
**		Bins the GANET data in numerous databases, returning the results in a crosstab format
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters: 
**
**		Auth: mem
**		Date: 02/17/2003
**			  11/23/2005 mem - Added brackets around @CurrentMTDB as needed to allow for DBs with dashes in the name
**     
*****************************************************/
	-- Useful long DB list: 'MT_BSA_P47,MT_BSA_X100,MT_Cytomegalovirus_P43,MT_Deinococcus_P12,MT_Deinococcus_P104,MT_G_Metallireducens_P99,MT_G_Sulfurreducens_P98,MT_Human_P65,MT_Human_P97,MT_Mouse_P75,MT_R_Sphaeroides_P61,MT_Shewanella_P14,MT_Shewanella_P96,MT_Shewanella_X103,MT_Shewanella_X105,MT_Software_Q84,MT_Synechocystis_P30,MT_Y_Pestis_P102,MT_Yeast_P51'
	
	@DBList varchar(2048) = '',				-- Comma separated list of database names; if blank, will use the 5 most recent databases in T_MT_Database_List
	@NominalBinCount int = 40,				-- Number of Bins between 0 and 1
	@Normalize tinyint = 1,
	@message varchar(1024) = '' OUTPUT
AS
	Set NOCOUNT ON

	Declare @Sql varchar(8000),
			@CrosstabSql varchar(7000),
			@CurrentMTDB varchar(100),
			@CurrentMTDBShort varchar(100),
			@strNominalBinCount varchar(11)
			
	Declare @Done int,
			@myError int,
			@CommaLoc int,
			@MatchCount int,
			@Divisor float
	
	Set @myError = 0

	If (Len(IsNull(@DBList, '')) = 0)
	Begin
		Set @DBList = ''
		
		SELECT @DBList = @DBList + InnerQ.MTL_Name + ','
		FROM (	SELECT TOP 5 MTL_Name
				FROM T_MT_Database_List
				WHERE MTL_State <> 100
				ORDER BY MTL_Last_Update DESC
			 ) AS InnerQ
		ORDER BY MTL_Name
	End

	If IsNull(@NominalBinCount, 0) < 1
		Set @NominalBinCount = 10
		
	Set @strNominalBinCount = Convert(varchar(11), @NominalBinCount)
	
	CREATE TABLE #GANETStats (
		DBName varchar(100),
		NetBin decimal(9,4),
		NetBinCount decimal (9,3)
	)


	If (Right(@DBList,1) <> ',')
		Set @DBList = @DBList + ','
		
	Set @CrosstabSql = ''
	
	Set @CommaLoc = CharIndex(',', @DBList)
	While @CommaLoc > 1
	Begin
		Set @CurrentMTDB = LTrim(Left(@DBList, @CommaLoc-1))
		Set @DBList = SubString(@DBList, @CommaLoc+1, Len(@DBList))

		-- Make sure @CurrentMTDB exists in T_MT_Database_List
		SELECT @MatchCount = COUNT(MTL_ID)
		FROM T_MT_Database_List
		WHERE MTL_Name = (@CurrentMTDB) AND MTL_State <> 100
		
		If IsNull(@MatchCount,0) > 0
		Begin
			
			Set @Sql = ''
			Set @Sql = @Sql + ' INSERT INTO #GANETStats'
			Set @Sql = @Sql + ' SELECT ''' + @CurrentMTDB + ''' AS DBName, NetBin, COUNT(NetBin) AS NetBinCount'
			Set @Sql = @Sql + ' FROM (	SELECT ROUND(Avg_GANET * ' + LTrim(RTrim(@strNominalBinCount)) + ', 0) / ' + LTrim(RTrim(@strNominalBinCount)) + ' AS NetBin'
			Set @Sql = @Sql + '			FROM [' + @CurrentMTDB + '].dbo.T_Mass_Tags_NET) InnerQ'
			Set @Sql = @Sql + '	WHERE (NOT (NetBin IS NULL))'
			Set @Sql = @Sql + ' GROUP BY NetBin'
			Set @Sql = @Sql + ' ORDER BY NetBin'
			
			Exec (@Sql)
			--
			SELECT @myError = @@Error
			--
			IF @myError <> 0
			Begin
				Set @message = 'Error getting stats for ' + @CurrentMTDB
				Goto Done
			End

	/*
			If (@Normalize <> 0)
			Begin
				-- Normalize the data for this database (This is now done below after #GANETStats is fully populated)
				SELECT @Divisor = SUM(NetBinCount)
				FROM #GANETStats
				WHERE DBName = (@CurrentMTDB)

				If IsNull(@Divisor, 0) > 0
					UPDATE #GANETStats 
					SET NetBinCount = 100.0 * NetBinCount / + @Divisor
			End
	*/
			
			Set @CommaLoc = CharIndex(',', @DBList)
			
			Set @CurrentMTDBShort = @CurrentMTDB
			
			If Upper(Left(@CurrentMTDBShort,3)) = 'MT_'
				Set @CurrentMTDBShort = Substring(@CurrentMTDBShort,4,Len(@CurrentMTDBShort)-3)
				
			-- Add the next term onto @CrossTabSql
			Set @CrossTabSql = @CrossTabSql + ','
			Set @CrossTabSql = @CrossTabSql + 'MAX(CASE WHEN DBName= ''' + @CurrentMTDB + ''''
			Set @CrossTabSql = @CrossTabSql + ' THEN Convert(varchar(9), NetBinCount)'
			Set @CrossTabSql = @CrossTabSql + ' ELSE'
			Set @CrossTabSql = @CrossTabSql + ' '''''
			Set @CrossTabSql = @CrossTabSql + ' END) AS ' + @CurrentMTDBShort
		End
	End	


	-- Normalize the data
	If (@Normalize <> 0)
	Begin
		UPDATE #GANETStats
		SET	 NetBinCount = 100.0 * NetBinCount / SumQ.BinCountSum
		FROM #GANETStats,
				(	SELECT DBName, SUM(NetBinCount) AS BinCountSum
					FROM #GANETStats
					GROUP BY DBName
				) AS SumQ
		WHERE	#GANETStats.DBName = SumQ.DBName AND 
				IsNull(SumQ.BinCountSum, 0) > 0
		--
		SELECT @myError = @@Error
		--
		IF @myError <> 0
		Begin
			Set @message = 'Error normalizing data'
			Goto Done
		End
	End
	
			
	Exec ( 'SELECT NetBin ' + @CrossTabSql + ' FROM #GANETStats GROUP BY NetBin ORDER BY NetBin')
	--
	SELECT @myError = @@Error
	--
	IF @myError <> 0
	Begin
		Set @message = 'Error creating crosstabular data'
		Goto Done
	End
	
Done:

	Return @myError


GO
GRANT EXECUTE ON [dbo].[GANETStatsByDB] TO [DMS_SP_User]
GO

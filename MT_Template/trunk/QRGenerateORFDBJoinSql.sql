SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[QRGenerateORFDBJoinSql]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[QRGenerateORFDBJoinSql]
GO


CREATE Procedure dbo.QRGenerateORFDBJoinSql
/****************************************************	
**  Desc: Generates the sql required to join the 
**		  Quantitation Rollup queries to the T_ORF table
**		  in the ORF Database defined for this mass tag database
**
**  Return values: 0 if success, otherwise, error code
**
**  Parameters: OrfDescriptionSqlJoin output parameter
**
**  Auth:	mem
**	Date:	04/09/2004
**			10/05/2004 mem - Updated for new MTDB schema
**			12/01/2005 mem - Added brackets around @ProteinDBName as needed to allow for DBs with dashes in the name
**
****************************************************/
(
	@OrfDescriptionSqlJoin varchar(1024) = '' OUTPUT					-- Sql to join the Quantitation Rollup queries to the T_ORF table
)
AS

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	Declare	@ProteinDBName varchar(255),
			@UQ varchar(1024)

	Declare @Continue int
	Declare @ODBID int
	
	Set @ProteinDBName = ''
	Set @OrfDescriptionSqlJoin = ''


	-- Create a temporary table
	CREATE TABLE #ProteinDBList (
		ODB_ID int NOT NULL,
		Protein_DB_Name varchar(128) NOT NULL
	)
	

	-- Populate the temporary table with the Protein DBs corresponding to the proteins in T_Proteins
	-- Link in the Protein DB number, since we'll use that as part of the join
	-- We're joining to table master.dbo.sysdatabases in order to only list Protein DBs that actually exist
	INSERT INTO #ProteinDBList (ODB_ID, Protein_DB_Name)
	SELECT DISTINCT ODL.ODB_ID, ODL.ODB_Name
	FROM MT_Main.dbo.T_ORF_Database_List ODL INNER JOIN
		master.dbo.sysdatabases SD ON 
		ODL.ODB_Name = SD.name INNER JOIN
		T_Proteins ON ODL.ODB_ID = T_Proteins.Protein_DB_ID
	--
	SELECT @myError = @@error, @myRowCount = @@RowCount
    
	If @myRowCount > 0
	Begin
		-- Construct the union query that grabs protein descriptions

		Set @UQ	 = ''
	
		Set @ODBID = 0
		Set @Continue = 1
		While @Continue = 1
		Begin
			SELECT TOP 1 @ODBID = ODB_ID, @ProteinDBName = Protein_DB_Name
			FROM #ProteinDBList
			WHERE ODB_ID > @ODBID
			ORDER BY ODB_ID
			--
			SELECT @myError = @@error, @myRowCount = @@RowCount
			
			If @myRowCount <> 1
				Set @Continue = 0
			Else
			Begin
				If Len(@UQ) > 0
					Set @UQ = @UQ + ' UNION '
				
				Set @UQ = @UQ + 'SELECT ' + Convert(varchar(9), @ODBID) + ' AS ODB_ID,ORF_ID,'
				Set @UQ = @UQ + 'Convert(varchar(512), Description_From_Fasta) AS Protein_Description'
				Set @UQ = @UQ + ' FROM [' + @ProteinDBName + '].dbo.T_ORF'
			End
			
		End
		
		Set @OrfDescriptionSqlJoin = ' LEFT OUTER JOIN (' + @UQ + ') ORFInfo ON T_Proteins.Protein_DB_ID = ORFInfo.ODB_ID AND T_Proteins.Protein_ID = ORFInfo.ORF_ID '
		
	End

	Return 0


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[QRGenerateORFDBJoinSql]  TO [DMS_SP_User]
GO


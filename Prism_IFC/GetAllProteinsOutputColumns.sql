/****** Object:  StoredProcedure [dbo].[GetAllProteinsOutputColumns] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.GetAllProteinsOutputColumns
/****************************************************
**
**	Desc: 
**	Returns the valid column names for the 
**  GetAllProteins SP
**        
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**	  @message				-- Status/error message output
**
**		Auth: mem
**		Date: 4/12/2004
**			  4/14/2004 mem - Added Data_Type column to output ResultSet
**            9/23/2004 grk - Changed ORF to Protein (superseded GetAllORFsOutputColumns)
**			 11/20/2004 mem - Updated to demonstrate use of T_SP_Glossary
**    
*****************************************************/
(
	@message varchar(512) = '' output
)
As
	set nocount on

	declare @myError int
	set @myError = 0

	declare @myRowCount int
	set @myRowCount = 0
	
	set @message = ''
	declare @result int
	
	---------------------------------------------------
	-- create a temporary table to hold the column names
	---------------------------------------------------

	CREATE TABLE #OutputColumns (
		UniqueID int IDENTITY (1, 1) NOT NULL ,
		Column_Name varchar (255) NOT NULL ,
		Data_Type varchar (255) NOT NULL
	)   

	---------------------------------------------------
	-- populate the table with the valid column names
	---------------------------------------------------
	INSERT INTO #OutputColumns (Column_Name, Data_Type) Values ('Protein_Name', 'varchar')
	INSERT INTO #OutputColumns (Column_Name, Data_Type) Values ('Protein_Description', 'varchar')
	INSERT INTO #OutputColumns (Column_Name, Data_Type) Values ('Protein_Location_Start', 'int')
	INSERT INTO #OutputColumns (Column_Name, Data_Type) Values ('Protein_Location_Stop', 'int')
	INSERT INTO #OutputColumns (Column_Name, Data_Type) Values ('Protein_Monoisotopic_Mass', 'float')
	INSERT INTO #OutputColumns (Column_Name, Data_Type) Values ('Protein_Sequence', 'text')
	
	---------------------------------------------------
	-- return the names in a ResultSet
	---------------------------------------------------

	-- Can use the following once T_SP_Glossary is populated
	/*
	SELECT Column_Name, Data_Type_Name AS Data_Type
	FROM T_SP_Glossary INNER JOIN T_SP_List 
		 ON T_SP_Glossary.SP_ID = T_SP_List.SP_ID
	WHERE T_SP_List.SP_Name = 'GetAllProteinsOutputColumns' AND 
		  T_SP_Glossary.Direction_ID = 3
	ORDER BY Ordinal_Position
	*/
	
	SELECT Column_Name, Data_Type
	FROM #OutputColumns
	ORDER BY UniqueID

Done:
	return @myError


GO
GRANT EXECUTE ON [dbo].[GetAllProteinsOutputColumns] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetAllProteinsOutputColumns] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetAllProteinsOutputColumns] TO [MTS_DB_Lite] AS [dbo]
GO

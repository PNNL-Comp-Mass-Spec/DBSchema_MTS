SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[QRPeptideCrosstabOutputColumns]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[QRPeptideCrosstabOutputColumns]
GO

CREATE PROCEDURE dbo.QRPeptideCrosstabOutputColumns
	(
	@message varchar(512) = '' output
	)
AS
	set nocount on

	declare @myError int
	set @myError = 0
	
	set @message = ''
	---------------------------------------------------
	-- create a temporary table to hold the column names
	---------------------------------------------------
	
	CREATE TABLE #OutputColumns (
		UniqueID int IDENTITY (1, 1) NOT NULL ,
		Column_Name varchar (255) NOT NULL ,
		Data_Type varchar (255) NOT NULL,
		Description varchar (255) NOT NULL
	)   

	---------------------------------------------------
	-- populate the table with the valid column names
	---------------------------------------------------
	INSERT INTO #OutputColumns (Column_Name, Data_Type, Description) Values ('MT_Abundance', 'varchar', 'Abundance')
	INSERT INTO #OutputColumns (Column_Name, Data_Type, Description) Values ('ER', 'varchar', 'Expression Ratio')
	INSERT INTO #OutputColumns (Column_Name, Data_Type, Description) Values ('Mass_Error_PPM_Avg', 'varchar', 'Mass Error PPM')
	INSERT INTO #OutputColumns (Column_Name, Data_Type, Description) Values ('UMC_MatchCount_Avg', 'varchar', 'UMC Match Count')
	INSERT INTO #OutputColumns (Column_Name, Data_Type, Description) Values ('SingleMT_MassTagMatchingIonCount', 'varchar', 'MT Matching Ion Count')
	INSERT INTO #OutputColumns (Column_Name, Data_Type, Description) Values ('SingleMT_FractionScansMatchingSingleMT', 'varchar', 'Fraction Scans Matching Single MT')
	INSERT INTO #OutputColumns (Column_Name, Data_Type, Description) Values ('ReplicateCountAvg', 'varchar', 'Replicate Count')
	INSERT INTO #OutputColumns (Column_Name, Data_Type, Description) Values ('FractionCountAvg', 'varchar', 'Fraction Count')
	INSERT INTO #OutputColumns (Column_Name, Data_Type, Description) Values ('TopLevelFractionCount', 'varchar', 'Top Level Fraciton Count')

	---------------------------------------------------
	-- return the names in a ResultSet
	---------------------------------------------------
	
	SELECT Column_Name, Data_Type, Description
	FROM #OutputColumns
	ORDER BY UniqueID

Done:
	return @myError

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[QRPeptideCrosstabOutputColumns]  TO [DMS_SP_User]
GO


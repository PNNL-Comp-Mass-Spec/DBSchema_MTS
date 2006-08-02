SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[QRProteinCrosstabOutputColumns]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[QRProteinCrosstabOutputColumns]
GO

CREATE PROCEDURE dbo.QRProteinCrosstabOutputColumns
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
	INSERT INTO #OutputColumns (Column_Name, Data_Type, Description) Values ('Abundance_Average', 'varchar', 'Abundance')
	INSERT INTO #OutputColumns (Column_Name, Data_Type, Description) Values ('ER_Average', 'varchar', 'Expression Ratio')
	INSERT INTO #OutputColumns (Column_Name, Data_Type, Description) Values ('MassTagCountUniqueObserved', 'varchar', 'MT Count Unique')
	INSERT INTO #OutputColumns (Column_Name, Data_Type, Description) Values ('MassTagCountUsedForAbundanceAvg', 'varchar', 'MT Count Used For Abundance Calc')
	INSERT INTO #OutputColumns (Column_Name, Data_Type, Description) Values ('Full_Enzyme_Count', 'varchar', 'Full Enzyme Count')
	INSERT INTO #OutputColumns (Column_Name, Data_Type, Description) Values ('Full_Enzyme_No_Missed_Cleavage_Count', 'varchar', 'Full Enzyme No Missed Cleavage Count')
	INSERT INTO #OutputColumns (Column_Name, Data_Type, Description) Values ('Partial_Enzyme_Count', 'varchar', 'Partial Enzyme Count')
	INSERT INTO #OutputColumns (Column_Name, Data_Type, Description) Values ('ORF_Coverage_Residue_Count', 'varchar', 'ORF Coverage Residue Count')
	INSERT INTO #OutputColumns (Column_Name, Data_Type, Description) Values ('ORF_Coverage_Fraction', 'varchar', 'ORF Coverage Fraction')
	INSERT INTO #OutputColumns (Column_Name, Data_Type, Description) Values ('Potential_Full_Enzyme_Count', 'varchar', 'Potential Full Enzyme Count')
	INSERT INTO #OutputColumns (Column_Name, Data_Type, Description) Values ('Potential_Partial_Enzyme_Count', 'varchar', 'Potential Partial Enzyme Count')
	INSERT INTO #OutputColumns (Column_Name, Data_Type, Description) Values ('Potential_ORF_Coverage_Residue_Count', 'varchar', 'Potential ORF Coverage Residue Count')
	INSERT INTO #OutputColumns (Column_Name, Data_Type, Description) Values ('Potential_ORF_Coverage_Fraction', 'varchar', 'Potential ORF Coverage Fraction')
	INSERT INTO #OutputColumns (Column_Name, Data_Type, Description) Values ('FractionScansMatchingSingleMassTag', 'varchar', 'Fraction Scans Matching MT')

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

GRANT  EXECUTE  ON [dbo].[QRProteinCrosstabOutputColumns]  TO [DMS_SP_User]
GO


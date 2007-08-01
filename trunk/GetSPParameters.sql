/****** Object:  UserDefinedFunction [dbo].[GetSPParameters] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION dbo.GetSPParameters
/****************************************************
**
**	Desc:	Returns the input and output parameters for a 
**			given stored procedure
**        
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**	  @procedure_name				-- Stored procedure to examine
**
**		Auth: mem
**		Date: 11/20/2004
**    
*****************************************************/
(
	@procedure_name nvarchar(390)
)
RETURNS  @retColumns TABLE (Parameter_Name sysname, 
							Parameter_Type smallint,
							Data_Type smallint,
							Data_Type_Name sysname,
							Length int,
							[Precision] int,
							[Scale] int,
							Ordinal_Position int
							)
AS
	BEGIN
	
		if @procedure_name is null
			set @procedure_name = ''

/*
** Straightforward Select statement, provided by Gary Kiebel
*/
		INSERT INTO @retColumns
		SELECT 
			syscolumns.name AS Parameter_Name, 
			convert(smallint, 1 + syscolumns.isoutparam) AS Parameter_Type, 
			syscolumns.type as Data_Type,
			systypes.name as Data_Type_Name, 
			syscolumns.Length as Length, 
			syscolumns.prec AS [Precision],
			syscolumns.Scale AS [Scale],
			syscolumns.colid AS Ordinal_Position
			--syscolumns.usertype
		FROM 
			sysobjects INNER JOIN
			syscolumns ON sysobjects.id = syscolumns.id INNER JOIN
			systypes ON syscolumns.xtype = systypes.xtype
		WHERE 
			(sysobjects.xtype = 'P') AND 
			(sysobjects.name = @procedure_name)
		ORDER BY Ordinal_Position


/*
** Complex Select statement, extracted from the sp_sproc_columns system stored procedure
*/

/*
	    DECLARE @group_num_lower smallint
		DECLARE @group_num_upper smallint
		DECLARE @procedure_id int

		set @group_num_lower = 1
		set @group_num_upper = 32767			


		-- Get Object ID
		SELECT @procedure_id = object_id(@procedure_name)
	
		INSERT INTO @retColumns
		SELECT
	--		convert(sysname,DB_NAME()) as PROCEDURE_QUALIFIER ,
	--		convert(sysname,USER_NAME(o.uid)) as PROCEDURE_OWNER,
	--		convert(nvarchar(134),o.name +';'+ ltrim(str(c.number,5))) as PROCEDURE_NAME,
			convert(sysname,c.name) as Parameter_Name,
			convert(smallint, 1+c.isoutparam) as Parameter_Type,
			c.type as Data_Type,
			t.name as Data_Type_Name,
			convert(int,	case
							when type_name(d.ss_dtype) IN ('numeric','decimal') then	-- decimal/numeric types
								OdbcPrec(c.xtype,c.Length,c.xprec)+2
							else
								isnull(d.Length, c.Length)
							end
					) AS Length,
			c.prec AS [Precision],
			c.Scale AS [Scale]
			convert(int, c.colid) as Ordinal_Position
		FROM
			syscolumns c INNER JOIN
			sysobjects o ON c.id = o.id INNER JOIN
			master.dbo.spt_datatype_info d ON c.xtype = d.ss_dtype AND 
			c.Length = ISNULL(d.fixlen, c.Length) INNER JOIN
			systypes t ON c.xusertype = t.xusertype
		WHERE
			o.id = @procedure_id
			AND c.name like '%'							-- Could use this to filter for certain parameter names
			AND d.ODBCVer is null
			AND isnull(d.AUTO_INCREMENT,0) = 0
			AND (o.type in ('P', 'TF', 'IF') OR (len(c.name) > 0 and o.type = 'FN'))
			AND ((c.number between @group_num_lower and @group_num_upper)
				    OR (c.number = 0 and o.type = 'FN'))
	--	ORDER BY PROCEDURE_QUALIFIER, PROCEDURE_OWNER, Ordinal_Position 
		ORDER BY Ordinal_Position 
*/

		
		RETURN
	END

GO

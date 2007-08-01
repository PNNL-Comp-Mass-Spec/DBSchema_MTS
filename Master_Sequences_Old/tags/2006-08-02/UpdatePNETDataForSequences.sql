SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[UpdatePNETDataForSequences]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[UpdatePNETDataForSequences]
GO

CREATE PROCEDURE dbo.UpdatePNETDataForSequences
/****************************************************
** 
**	Desc: Updates the PNET values in T_Sequence using the data in @PNetTableName
**        Processes each of the peptide sequences in the given table (typically located in TempDB)
**
**		  The peptide sequences table must contain the columns Peptide_ID, Peptide, and Seq_ID
**		  A second table must also be provided to store the unique sequence information
**		  This table must contain the columns Seq_ID, Clean_Sequence, Mod_Count, and Mod_Description
**
**		Return values: 0: success, otherwise, error code
**
**	Auth:	mem
**	Date:	05/13/2006
**    
*****************************************************/
(
	@PNetTableName varchar(256),			-- Table with the Seq_ID and PNET data
	@Updatecount int=0 output,				-- Number of sequences updated
	@message varchar(256) = '' output
)
As
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	set @message = ''

	declare @S nvarchar(1024)
	declare @result int
	
	set @S = ''
	set @S = @S + ' UPDATE MST'
	set @S = @S + ' SET GANET_Predicted = PNETData.PNET, Last_Affected = GetDate()'
	set @S = @S + ' FROM T_Sequence AS MST INNER JOIN'
	set @S = @S +   ' ' + @PNetTableName + ' AS PNETData ON MST.Seq_ID = PNETData.Seq_ID'
	set @S = @S + ' WHERE MST.GANET_Predicted <> PNETData.PNET OR MST.GANET_Predicted Is Null'

	exec @result = sp_executesql @S
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	Set @Updatecount = @myRowCount
	
Done:
	Return @myError

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[UpdatePNETDataForSequences]  TO [DMS_SP_User]
GO


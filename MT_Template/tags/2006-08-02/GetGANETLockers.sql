SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[GetGANETLockers]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[GetGANETLockers]
GO


CREATE Procedure dbo.GetGANETLockers
/****************************************************	
**  Desc: Returns GANET lockers for this DB
**
**  Return values: 0 if success, otherwise, error code 
**
**  Parameters: none
**
**  Auth:	mem
**	Date:	01/02/2004
**			03/03/2005 mem - Now only returning peptides with state = 1
**			05/16/2005 mem - Switched to always use the Avg_GANET column for the NET value; switched to using Seq_ID for the Locker ID
**			05/20/2005 mem - Switched to obtain Peptide sequence and mass from T_Mass_Tags
**			12/15/2005 mem - Updated to call GetInternalStandards
**
****************************************************/
As

	Set NoCount On

	Declare @ReturnCode int
	Set @ReturnCode = 0

	EXEC @ReturnCode = GetInternalStandards 0, 'PepChromeA'

/*
**	Old Code:
	SELECT	GL.Seq_ID AS GANET_Locker_ID, 
			GL.Description, 
			MT.Peptide, 
			MT.Monoisotopic_Mass, 
			GL.Avg_GANET AS GANET, 
			GL.Charge_Minimum, 
			GL.Charge_Maximum, 
			GL.Charge_Highest_Abu
	FROM T_GANET_Lockers GL INNER JOIN
		 T_Mass_Tags MT ON GL.Seq_ID = MT.Mass_Tag_ID
	WHERE GL.GANET_Locker_State = 1
	ORDER BY MT.Monoisotopic_Mass
	--
	Set @ReturnCode = @@Error
*/
	
	Return @ReturnCode


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[GetGANETLockers]  TO [DMS_SP_User]
GO


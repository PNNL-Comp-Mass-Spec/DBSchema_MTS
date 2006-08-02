SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[AddUpdateQuantMDIDMapping]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[AddUpdateQuantMDIDMapping]
GO



CREATE PROCEDURE dbo.AddUpdateQuantMDIDMapping
/****************************************************
**
**	Desc: Adds a new entry to T_Quantitation_MDIDs
**
**	Return values: 0: success, otherwise, error code
**                 Also returns the Q_MDID_ID value
**                 of the entry via the @QMDIDID parameter
**
**	Parameters: 
**
**		Auth: mem
**		Date: 9/12/2003
**
**      
*****************************************************/
	@QuantitationID int,
	@MDID int,
	@Replicate smallint = 1,
	@Fraction smallint = 1,
	@TopLevelFraction smallint = 1,
	@QMDIDID int = Null output ,
	@mode varchar(12) = 'add', -- or 'update'
	@message varchar(512) = '' output 
As
	Set Nocount On

	declare @myError int,
			@myRowCount int,
			@hit int
			
	set @myError = 0
	set @myRowCount = 0
	
	set @message = ''
	
	---------------------------------------------------
	-- If updating, make sure entry is already in T_Quantitation_MDIDs
	---------------------------------------------------

	If @mode = 'update'
	Begin
		set @hit = 0
		--
		SELECT @hit = Count(*)
		FROM T_Quantitation_MDIDs
		WHERE (Q_MDID_ID = @QMDIDID)
		--
		SELECT @myError = @@Error, @myRowCount = @@Rowcount
		--
		If @myError <> 0
		Begin
			set @message = 'Error checking for existing Quantitation MDID mapping "' + Convert(varchar(19), @QMDIDID) + '"'
			RAISERROR (@message, 10, 1)
			return 51001
		End

		-- cannot update a non-existent entry
		--
		If @hit = 0 and @mode = 'update'
		Begin
			set @message = 'Cannot update: Requested Quantitation MDID "' + Convert(varchar(19), @QMDIDID) + '" is not in database '
			RAISERROR (@message, 10, 1)
			return 51002
		End
	End

	
	---------------------------------------------------
	-- Validate that QuantitationID exists in database
	---------------------------------------------------
	
	set @hit = 0
	--
	SELECT @hit = COUNT(*)
	FROM T_Quantitation_Description
	WHERE (Quantitation_ID = @QuantitationID)
	--
	SELECT @myError = @@Error, @myRowCount = @@Rowcount
	--
	If @myError <> 0
	Begin
		set @message = 'Could not cross Quantitation ID'
		RAISERROR (@message, 10, 1)
		return 51003
	End
	
	If @hit = 0
	Begin
		set @message = 'Quantitation ID ' + convert(varchar(19), @QuantitationID) + ' could not be found in table' 
		RAISERROR (@message, 10, 1)
		return 51004
	End
	
	---------------------------------------------------
	-- Action for add mode
	---------------------------------------------------
	
	If @Mode = 'add'
	Begin

		set @QMDIDID = 0

		INSERT INTO T_Quantitation_MDIDs
		(
			Quantitation_ID, 
			MD_ID,
			[Replicate],
			Fraction, 
			TopLevelFraction 
		)
		VALUES
		(
			@QuantitationID,
			@MDID,
			@Replicate,
			@Fraction,
			@TopLevelFraction
		)	
		--
		SELECT @myError = @@Error, @myRowCount = @@Rowcount, @QMDIDID = @@Identity
		--
		If @myError <> 0
		Begin
			set @message = 'Insert operation failed for Quantitation ID ' + convert(varchar(19), @QuantitationID)
			RAISERROR (@message, 10, 1)
			return 51005
		End
		

	End -- add mode

	---------------------------------------------------
	-- action for update mode
	---------------------------------------------------
	--
	If @Mode = 'update' 
	Begin
		set @myError = 0
		--
		UPDATE T_Quantitation_MDIDs
		SET 
			Quantitation_ID = @QuantitationID, 
			MD_ID = @MDID,
			[Replicate] = @Replicate,
			Fraction = @Fraction, 
			TopLevelFraction = @TopLevelFraction
		WHERE (Q_MDID_ID = @QMDIDID)
		--

		SELECT @myError = @@Error, @myRowCount = @@Rowcount
		--
		If @myError <> 0 or @myRowCount <> 1
		Begin
			set @message = 'Update operation failed'
			RAISERROR (@message, 10, 1)
			return 51006
		End
	End -- update mode

	Return 0	



GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[AddUpdateQuantMDIDMapping]  TO [DMS_SP_User]
GO


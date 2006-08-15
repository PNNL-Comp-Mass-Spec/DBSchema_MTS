/****** Object:  Table [dbo].[T_Process_Config] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Process_Config](
	[Process_Config_ID] [int] IDENTITY(100,1) NOT NULL,
	[Name] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Value] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
 CONSTRAINT [PK_T_Process_Config] PRIMARY KEY NONCLUSTERED 
(
	[Process_Config_ID] ASC
)WITH FILLFACTOR = 90 ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_Process_Config_UniqueNameValue] ******/
CREATE UNIQUE CLUSTERED INDEX [IX_T_Process_Config_UniqueNameValue] ON [dbo].[T_Process_Config] 
(
	[Name] ASC,
	[Value] ASC
)WITH FILLFACTOR = 90 ON [PRIMARY]
GO

/****** Object:  Trigger [dbo].[trig_iu_T_Process_Config] ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER OFF
GO


CREATE TRIGGER [dbo].[trig_iu_T_Process_Config] ON [dbo].[T_Process_Config] 
FOR INSERT, UPDATE
/********************************************************
**
**	Desc: 
**		Validates that the inserted or updated entries in T_Process_Config
**		  do not result in too many entries for the given Name
**		In addition, raises an error if the Value field contains Cr or Lf
**
**	Auth:	mem
**	Date:	03/07/2006
**			07/03/2006 mem
**
*********************************************************/
AS
Begin
	If @@RowCount = 0
		Return

	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	Declare @CountPresent int
	Declare @ErrorMessage varchar(256)

	if update([Name])
	Begin	-- <a1>
		-- Make sure the table does not have too many entries for Name
		Declare @ProcessConfigIDMin int
		Declare @continue int

		Declare @MaxCountAllowed int
		Declare @ConfigName varchar(255)

		Set @ProcessConfigIDMin = 0
		Set @continue = 1
		While @continue = 1
		Begin	-- <b>
			SELECT TOP 1 @ProcessConfigIDMin = Process_Config_ID
			FROM inserted
			WHERE Process_Config_ID > @ProcessConfigIDMin
			ORDER BY Process_Config_ID
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount

			If @myRowCount = 0
				Set @continue = 0
			Else
			Begin	-- <c>
				Set @MaxCountAllowed = 99
				SELECT @MaxCountAllowed = PCP.Max_Occurrences,
					 @ConfigName = inserted.[Name]
				FROM T_Process_Config_Parameters PCP INNER JOIN 
					inserted on PCP.[Name] = inserted.[Name]
				WHERE inserted.Process_Config_ID = @ProcessConfigIDMin
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
		
				If @myRowCount > 0 AND @MaxCountAllowed < 99
				Begin	-- <d>
					SET @CountPresent = 0

					SELECT @CountPresent = COUNT(*)
					FROM inserted
					WHERE inserted.[Name] = @ConfigName

					SELECT @CountPresent = @CountPresent + COUNT(PC.Process_Config_ID)
					FROM T_Process_Config PC LEFT OUTER JOIN
						inserted ON PC.Process_Config_ID = inserted.Process_Config_ID
					WHERE PC.[Name] = @ConfigName AND inserted.Process_Config_ID IS NULL

					If @CountPresent > @MaxCountAllowed
					Begin	-- <e>
						-- Too many rows; raise an error
						Set @ErrorMessage = 'Error: Changes result in too many entries in T_Process_Config for Name = ''' + @ConfigName + '''; Maximum Count = ' + Convert(varchar(19), @MaxCountAllowed)
						RAISERROR (@ErrorMessage, 16, 1)
						ROLLBACK TRANSACTION
						set @continue = 0
					End	-- </e>
				End	-- </d>
			End	-- </c>
		End	-- </b>
	End	-- </a1>

	if update([Value])
	Begin -- <a2>
		-- See if any of the rows contain Cr or Lf
		-- Raise an error if found

		Declare @FirstName varchar(128)

		Set @CountPresent = 0
		SELECT @CountPresent = COUNT(*), @FirstName = Min(IsNull([Name], ''))
		FROM inserted
		WHERE CharIndex(char(10), IsNull(inserted.[Value], '')) > 0 OR
			  CharIndex(char(13), IsNull(inserted.[Value], '')) > 0
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		If @CountPresent > 0
		Begin
			Set @ErrorMessage = 'Error: The [Value] field cannot contain a carriage return or line feed; first entry with invalid character has [Name]=''' + @FirstName + ''''
			RAISERROR (@ErrorMessage, 16, 1)
			ROLLBACK TRANSACTION
		End

	End -- </a2>
End


GO
ALTER TABLE [dbo].[T_Process_Config]  WITH NOCHECK ADD  CONSTRAINT [FK_T_Process_Config_T_Process_Config_Parameters] FOREIGN KEY([Name])
REFERENCES [T_Process_Config_Parameters] ([Name])
GO
ALTER TABLE [dbo].[T_Process_Config] CHECK CONSTRAINT [FK_T_Process_Config_T_Process_Config_Parameters]
GO

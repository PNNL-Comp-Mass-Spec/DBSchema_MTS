if exists (select * from dbo.sysobjects where id = object_id(N'[T_Internal_Std_Composition]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Internal_Std_Composition]
GO

CREATE TABLE [T_Internal_Std_Composition] (
	[Internal_Std_Mix_ID] [int] NOT NULL ,
	[Seq_ID] [int] NOT NULL ,
	[Concentration] [varchar] (24) COLLATE SQL_Latin1_General_CP1_CI_AS NULL CONSTRAINT [DF_T_Internal_Std_Composition_Concentration] DEFAULT (''),
	CONSTRAINT [PK_T_Internal_Std_Composition] PRIMARY KEY  CLUSTERED 
	(
		[Internal_Std_Mix_ID],
		[Seq_ID]
	)  ON [PRIMARY] ,
	CONSTRAINT [FK_T_Internal_Std_Composition_T_Internal_Standards] FOREIGN KEY 
	(
		[Internal_Std_Mix_ID]
	) REFERENCES [T_Internal_Standards] (
		[Internal_Std_Mix_ID]
	),
	CONSTRAINT [FK_T_Internal_Std_Composition_T_Internal_Std_Components] FOREIGN KEY 
	(
		[Seq_ID]
	) REFERENCES [T_Internal_Std_Components] (
		[Seq_ID]
	)
) ON [PRIMARY]
GO



/****** Object:  Table [dbo].[T_DMS_Dataset_Info_Cached] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_DMS_Dataset_Info_Cached](
	[Dataset] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Experiment] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Organism] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Instrument] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Separation Type] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[LC Column] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Wellplate Number] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Well Number] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Dataset Int Std] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Type] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Operator] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Comment] [varchar](500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Rating] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Request] [int] NULL,
	[State] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Created] [datetime] NOT NULL,
	[Folder Name] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Dataset Folder Path] [varchar](1024) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Storage Folder] [varchar](256) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Storage] [varchar](1024) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Compressed State] [smallint] NULL,
	[Compressed Date] [datetime] NULL,
	[ID] [int] NOT NULL,
	[Acquisition Start] [datetime] NULL,
	[Acquisition End] [datetime] NULL,
	[Scan Count] [int] NULL,
	[File Size MB] [real] NULL,
	[PreDigest Int Std] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[PostDigest Int Std] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Instrument_Data_Purged] [tinyint] NOT NULL,
	[Last_Affected] [datetime] NULL,
 CONSTRAINT [PK_T_DMS_Dataset_Info_Cached] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Trigger [dbo].[trig_u_DMS_Dataset_Info_Cached] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Trigger [dbo].[trig_u_DMS_Dataset_Info_Cached] on [dbo].[T_DMS_Dataset_Info_Cached]
For Update
AS
	If @@RowCount = 0
		Return

	If  Update(Dataset) OR
		Update(Experiment) OR
		Update(Organism) OR
		Update(Instrument) OR
		Update([Separation Type]) OR
		Update([LC Column]) OR
		Update([Wellplate Number]) OR
		Update([Well Number]) OR
		Update([Dataset Int Std]) OR
		Update(Type) OR
		Update(Operator) OR
		Update(Comment) OR
		Update(Rating) OR
		Update(Request) OR
		Update(State) OR
		Update(Created) OR
		Update([Folder Name]) OR
		Update([Dataset Folder Path]) OR
		Update([Storage Folder]) OR
		Update(Storage) OR
		Update([Compressed State]) OR
		Update([Compressed Date]) OR
		Update(ID) OR
		Update([Acquisition Start]) OR
		Update([Acquisition End]) OR
		Update([Scan Count]) OR
		Update([File Size MB]) OR
		Update([PreDigest Int Std]) OR
		Update([PostDigest Int Std])
	Begin
			UPDATE T_DMS_Dataset_Info_Cached
			SET Last_Affected = GetDate()
			FROM T_DMS_Dataset_Info_Cached DS INNER JOIN 
				 inserted ON DS.ID = inserted.ID
	End

GO
ALTER TABLE [dbo].[T_DMS_Dataset_Info_Cached] ADD  CONSTRAINT [DF_T_DMS_Dataset_Info_Cached_Instrument_Data_Purged]  DEFAULT ((0)) FOR [Instrument_Data_Purged]
GO
ALTER TABLE [dbo].[T_DMS_Dataset_Info_Cached] ADD  CONSTRAINT [DF_T_DMS_Dataset_Info_Cached_Last_Affected]  DEFAULT (getdate()) FOR [Last_Affected]
GO

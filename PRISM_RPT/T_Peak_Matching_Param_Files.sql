/****** Object:  Table [dbo].[T_Peak_Matching_Param_Files] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Peak_Matching_Param_Files](
	[Param_File_ID] [int] IDENTITY(1000,1) NOT NULL,
	[Param_File_Name] [varchar](512) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Param_File_Description] [varchar](1024) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Date_Created] [datetime] NULL,
	[Date_Modified] [datetime] NULL,
	[Active] [smallint] NOT NULL,
	[PM_Task_Usage] [int] NULL,
 CONSTRAINT [PK_T_Peak_Matching_Param_Files] PRIMARY KEY NONCLUSTERED 
(
	[Param_File_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING ON

GO
/****** Object:  Index [IX_T_Peak_Matching_Param_Files] ******/
CREATE UNIQUE CLUSTERED INDEX [IX_T_Peak_Matching_Param_Files] ON [dbo].[T_Peak_Matching_Param_Files]
(
	[Param_File_Name] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_Peak_Matching_Param_Files] ADD  CONSTRAINT [DF_T_Peak_Matching_Param_Files_Param_File_Description]  DEFAULT ('') FOR [Param_File_Description]
GO
ALTER TABLE [dbo].[T_Peak_Matching_Param_Files] ADD  CONSTRAINT [DF_T_Peak_Matching_Param_Files_Date_Created]  DEFAULT (getdate()) FOR [Date_Created]
GO
ALTER TABLE [dbo].[T_Peak_Matching_Param_Files] ADD  CONSTRAINT [DF_T_Peak_Matching_Param_Files_Date_Modified]  DEFAULT (getdate()) FOR [Date_Modified]
GO
ALTER TABLE [dbo].[T_Peak_Matching_Param_Files] ADD  CONSTRAINT [DF_T_Peak_Matching_Param_Files_Active]  DEFAULT ((1)) FOR [Active]
GO

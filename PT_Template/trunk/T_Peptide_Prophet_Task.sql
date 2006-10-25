/****** Object:  Table [dbo].[T_Peptide_Prophet_Task] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Peptide_Prophet_Task](
	[Task_ID] [int] IDENTITY(1,1) NOT NULL,
	[Processing_State] [tinyint] NOT NULL,
	[Task_Created] [datetime] NULL,
	[Task_Start] [datetime] NULL,
	[Task_Finish] [datetime] NULL,
	[Task_AssignedProcessorName] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Transfer_Folder_Path] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[JobList_File_Name] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Results_File_Name] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
 CONSTRAINT [PK_T_Peptide_Prophet_Task] PRIMARY KEY CLUSTERED 
(
	[Task_ID] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_Peptide_Prophet_Task]  WITH CHECK ADD  CONSTRAINT [FK_T_Peptide_Prophet_Task_T_Peptide_Prophet_Task_State_Name] FOREIGN KEY([Processing_State])
REFERENCES [T_Peptide_Prophet_Task_State_Name] ([Processing_State])
GO
ALTER TABLE [dbo].[T_Peptide_Prophet_Task] CHECK CONSTRAINT [FK_T_Peptide_Prophet_Task_T_Peptide_Prophet_Task_State_Name]
GO

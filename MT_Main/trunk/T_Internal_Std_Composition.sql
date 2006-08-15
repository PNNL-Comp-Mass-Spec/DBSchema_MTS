/****** Object:  Table [dbo].[T_Internal_Std_Composition] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Internal_Std_Composition](
	[Internal_Std_Mix_ID] [int] NOT NULL,
	[Seq_ID] [int] NOT NULL,
	[Concentration] [varchar](24) COLLATE SQL_Latin1_General_CP1_CI_AS NULL CONSTRAINT [DF_T_Internal_Std_Composition_Concentration]  DEFAULT (''),
 CONSTRAINT [PK_T_Internal_Std_Composition] PRIMARY KEY CLUSTERED 
(
	[Internal_Std_Mix_ID] ASC,
	[Seq_ID] ASC
) ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_Internal_Std_Composition]  WITH CHECK ADD  CONSTRAINT [FK_T_Internal_Std_Composition_T_Internal_Standards] FOREIGN KEY([Internal_Std_Mix_ID])
REFERENCES [T_Internal_Standards] ([Internal_Std_Mix_ID])
GO
ALTER TABLE [dbo].[T_Internal_Std_Composition] CHECK CONSTRAINT [FK_T_Internal_Std_Composition_T_Internal_Standards]
GO
ALTER TABLE [dbo].[T_Internal_Std_Composition]  WITH CHECK ADD  CONSTRAINT [FK_T_Internal_Std_Composition_T_Internal_Std_Components] FOREIGN KEY([Seq_ID])
REFERENCES [T_Internal_Std_Components] ([Seq_ID])
GO
ALTER TABLE [dbo].[T_Internal_Std_Composition] CHECK CONSTRAINT [FK_T_Internal_Std_Composition_T_Internal_Std_Components]
GO

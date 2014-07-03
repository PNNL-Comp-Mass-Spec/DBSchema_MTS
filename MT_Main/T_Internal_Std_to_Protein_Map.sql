/****** Object:  Table [dbo].[T_Internal_Std_to_Protein_Map] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Internal_Std_to_Protein_Map](
	[Seq_ID] [int] NOT NULL,
	[Mass_Tag_Name] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Internal_Std_Protein_ID] [int] NOT NULL,
	[Cleavage_State] [tinyint] NULL,
	[Fragment_Number] [smallint] NULL,
	[Fragment_Span] [smallint] NULL,
	[Residue_Start] [int] NULL,
	[Residue_End] [int] NULL,
	[Repeat_Count] [smallint] NULL,
	[Terminus_State] [tinyint] NULL,
 CONSTRAINT [PK_T_Internal_Std_to_Protein_Map] PRIMARY KEY CLUSTERED 
(
	[Seq_ID] ASC,
	[Internal_Std_Protein_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_Internal_Std_to_Protein_Map]  WITH CHECK ADD  CONSTRAINT [FK_T_Internal_Std_to_Protein_Map_T_Internal_Std_Proteins] FOREIGN KEY([Internal_Std_Protein_ID])
REFERENCES [dbo].[T_Internal_Std_Proteins] ([Internal_Std_Protein_ID])
GO
ALTER TABLE [dbo].[T_Internal_Std_to_Protein_Map] CHECK CONSTRAINT [FK_T_Internal_Std_to_Protein_Map_T_Internal_Std_Proteins]
GO

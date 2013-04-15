/****** Object:  Table [dbo].[T_Alert_Exclusions] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Alert_Exclusions](
	[Category_Name] [nvarchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[FilterLikeClause] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
 CONSTRAINT [PK_T_Error_Exclusions] PRIMARY KEY CLUSTERED 
(
	[Category_Name] ASC,
	[FilterLikeClause] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_Alert_Exclusions]  WITH CHECK ADD  CONSTRAINT [FK_T_Alert_Exclusions_AlertSettings] FOREIGN KEY([Category_Name])
REFERENCES [AlertSettings] ([Name])
GO
ALTER TABLE [dbo].[T_Alert_Exclusions] CHECK CONSTRAINT [FK_T_Alert_Exclusions_AlertSettings]
GO

/****** Object:  Table [dbo].[T_Analysis_Filter_Flags] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Analysis_Filter_Flags](
	[Filter_ID] [int] NOT NULL,
	[Job] [int] NOT NULL,
 CONSTRAINT [PK_T_Analysis_Filter_Flags] PRIMARY KEY CLUSTERED 
(
	[Filter_ID] ASC,
	[Job] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_Analysis_Filter_Flags]  WITH CHECK ADD  CONSTRAINT [FK_T_Analysis_Filter_Flags_T_Analysis_Description] FOREIGN KEY([Job])
REFERENCES [T_Analysis_Description] ([Job])
GO
ALTER TABLE [dbo].[T_Analysis_Filter_Flags] CHECK CONSTRAINT [FK_T_Analysis_Filter_Flags_T_Analysis_Description]
GO

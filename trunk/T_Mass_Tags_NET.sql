/****** Object:  Table [dbo].[T_Mass_Tags_NET] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Mass_Tags_NET](
	[Mass_Tag_ID] [int] NOT NULL,
	[Min_GANET] [real] NULL,
	[Max_GANET] [real] NULL,
	[Avg_GANET] [real] NULL,
	[Cnt_GANET] [int] NULL,
	[StD_GANET] [real] NULL,
	[StdError_GANET] [real] NULL,
	[PNET] [real] NULL,
	[PNET_Variance] [real] NULL,
 CONSTRAINT [PK_T_Mass_Tags_NET] PRIMARY KEY CLUSTERED 
(
	[Mass_Tag_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_Mass_Tags_NET]  WITH NOCHECK ADD  CONSTRAINT [FK_T_Mass_Tags_NET_T_Mass_Tags] FOREIGN KEY([Mass_Tag_ID])
REFERENCES [T_Mass_Tags] ([Mass_Tag_ID])
GO
ALTER TABLE [dbo].[T_Mass_Tags_NET] CHECK CONSTRAINT [FK_T_Mass_Tags_NET_T_Mass_Tags]
GO

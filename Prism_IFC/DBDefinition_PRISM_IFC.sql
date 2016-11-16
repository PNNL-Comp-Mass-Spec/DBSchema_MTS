/****** Object:  Database [PRISM_IFC] ******/
CREATE DATABASE [PRISM_IFC] ON  PRIMARY 
( NAME = N'PRISM_IFC_Data', FILENAME = N'I:\SQLServerData\PRISM_IFC_Data.mdf' , SIZE = 9600KB , MAXSIZE = UNLIMITED, FILEGROWTH = 10%)
 LOG ON 
( NAME = N'PRISM_IFC_Log', FILENAME = N'H:\SQLServerData\PRISM_IFC_Log.ldf' , SIZE = 1280KB , MAXSIZE = UNLIMITED, FILEGROWTH = 10%)
 COLLATE SQL_Latin1_General_CP1_CI_AS
GO
ALTER DATABASE [PRISM_IFC] SET COMPATIBILITY_LEVEL = 100
GO
IF (1 = FULLTEXTSERVICEPROPERTY('IsFullTextInstalled'))
begin
EXEC [PRISM_IFC].[dbo].[sp_fulltext_database] @action = 'disable'
end
GO
ALTER DATABASE [PRISM_IFC] SET ANSI_NULL_DEFAULT ON 
GO
ALTER DATABASE [PRISM_IFC] SET ANSI_NULLS ON 
GO
ALTER DATABASE [PRISM_IFC] SET ANSI_PADDING OFF 
GO
ALTER DATABASE [PRISM_IFC] SET ANSI_WARNINGS ON 
GO
ALTER DATABASE [PRISM_IFC] SET ARITHABORT OFF 
GO
ALTER DATABASE [PRISM_IFC] SET AUTO_CLOSE OFF 
GO
ALTER DATABASE [PRISM_IFC] SET AUTO_CREATE_STATISTICS ON 
GO
ALTER DATABASE [PRISM_IFC] SET AUTO_SHRINK OFF 
GO
ALTER DATABASE [PRISM_IFC] SET AUTO_UPDATE_STATISTICS ON 
GO
ALTER DATABASE [PRISM_IFC] SET CURSOR_CLOSE_ON_COMMIT OFF 
GO
ALTER DATABASE [PRISM_IFC] SET CURSOR_DEFAULT  GLOBAL 
GO
ALTER DATABASE [PRISM_IFC] SET CONCAT_NULL_YIELDS_NULL OFF 
GO
ALTER DATABASE [PRISM_IFC] SET NUMERIC_ROUNDABORT OFF 
GO
ALTER DATABASE [PRISM_IFC] SET QUOTED_IDENTIFIER OFF 
GO
ALTER DATABASE [PRISM_IFC] SET RECURSIVE_TRIGGERS OFF 
GO
ALTER DATABASE [PRISM_IFC] SET  DISABLE_BROKER 
GO
ALTER DATABASE [PRISM_IFC] SET AUTO_UPDATE_STATISTICS_ASYNC OFF 
GO
ALTER DATABASE [PRISM_IFC] SET DATE_CORRELATION_OPTIMIZATION OFF 
GO
ALTER DATABASE [PRISM_IFC] SET TRUSTWORTHY OFF 
GO
ALTER DATABASE [PRISM_IFC] SET ALLOW_SNAPSHOT_ISOLATION OFF 
GO
ALTER DATABASE [PRISM_IFC] SET PARAMETERIZATION SIMPLE 
GO
ALTER DATABASE [PRISM_IFC] SET READ_COMMITTED_SNAPSHOT OFF 
GO
ALTER DATABASE [PRISM_IFC] SET HONOR_BROKER_PRIORITY OFF 
GO
ALTER DATABASE [PRISM_IFC] SET RECOVERY FULL 
GO
ALTER DATABASE [PRISM_IFC] SET  MULTI_USER 
GO
ALTER DATABASE [PRISM_IFC] SET PAGE_VERIFY CHECKSUM  
GO
ALTER DATABASE [PRISM_IFC] SET DB_CHAINING OFF 
GO
USE [PRISM_IFC]
GO
/****** Object:  User [D3E383] ******/
CREATE USER [D3E383] FOR LOGIN [PNL\D3E383] WITH DEFAULT_SCHEMA=[D3E383]
GO
/****** Object:  User [D3L243] ******/
CREATE USER [D3L243] FOR LOGIN [PNL\D3L243] WITH DEFAULT_SCHEMA=[D3L243]
GO
/****** Object:  User [d3m578] ******/
CREATE USER [d3m578] FOR LOGIN [PNL\D3M578] WITH DEFAULT_SCHEMA=[d3m578]
GO
/****** Object:  User [msdadmin] ******/
CREATE USER [msdadmin] FOR LOGIN [PNL\MSDADMIN] WITH DEFAULT_SCHEMA=[msdadmin]
GO
/****** Object:  User [MTAdmin] ******/
CREATE USER [MTAdmin] FOR LOGIN [mtadmin] WITH DEFAULT_SCHEMA=[dbo]
GO
/****** Object:  User [MTS_DB_Dev] ******/
CREATE USER [MTS_DB_Dev] FOR LOGIN [Pogo\MTS_DB_Dev]
GO
/****** Object:  User [MTS_DB_Lite] ******/
CREATE USER [MTS_DB_Lite] FOR LOGIN [Pogo\MTS_DB_Lite]
GO
/****** Object:  User [MTS_DB_Reader] ******/
CREATE USER [MTS_DB_Reader] FOR LOGIN [Pogo\MTS_DB_Reader]
GO
/****** Object:  User [MTUser] ******/
CREATE USER [MTUser] FOR LOGIN [mtuser] WITH DEFAULT_SCHEMA=[dbo]
GO
/****** Object:  User [PNL\D3J409] ******/
CREATE USER [PNL\D3J409] FOR LOGIN [PNL\D3J409] WITH DEFAULT_SCHEMA=[PNL\D3J409]
GO
/****** Object:  User [PNL\D3M580] ******/
CREATE USER [PNL\D3M580] FOR LOGIN [PNL\D3M580] WITH DEFAULT_SCHEMA=[PNL\D3M580]
GO
/****** Object:  User [PNL\svc-dms] ******/
CREATE USER [PNL\svc-dms] FOR LOGIN [PNL\svc-dms] WITH DEFAULT_SCHEMA=[PNL\svc-dms]
GO
GRANT CONNECT TO [D3E383] AS [dbo]
GO
GRANT CONNECT TO [D3J410] AS [dbo]
GO
GRANT CONNECT TO [D3L243] AS [dbo]
GO
GRANT CONNECT TO [d3m306] AS [dbo]
GO
GRANT CONNECT TO [d3m578] AS [dbo]
GO
GRANT CONNECT TO [msdadmin] AS [dbo]
GO
GRANT CONNECT TO [MTAdmin] AS [dbo]
GO
GRANT CONNECT TO [MTS_DB_Dev] AS [dbo]
GO
GRANT SHOWPLAN TO [MTS_DB_Dev] AS [dbo]
GO
GRANT CONNECT TO [MTS_DB_Lite] AS [dbo]
GO
GRANT SHOWPLAN TO [MTS_DB_Lite] AS [dbo]
GO
GRANT CONNECT TO [MTS_DB_Reader] AS [dbo]
GO
GRANT SHOWPLAN TO [MTS_DB_Reader] AS [dbo]
GO
GRANT CONNECT TO [MTUser] AS [dbo]
GO
GRANT SHOWPLAN TO [MTUser] AS [dbo]
GO
GRANT CONNECT TO [PNL\svc-dms] AS [dbo]
GO
ALTER DATABASE [PRISM_IFC] SET  READ_WRITE 
GO

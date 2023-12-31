USE [DigitalLibrary]
GO
/****** Object:  StoredProcedure [dbo].[WFSP_AC_SUCF28]    Script Date: 12/03/2017 09:38:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		<Hale Kavoosi>
-- Create date: <12/03/2017>
-- Description:	<Contract Cost Report>

-- =============================================
ALTER PROCEDURE [dbo].[WFSP_AC_SUCF28] 

	@DocumentCode int--شماره رکورد جاری
	,@IsCompile Bit	
	,@Button NVARCHAR(MAX)

	AS
	BEGIN
	---------------------------------------------------------------------------------------------	
	DECLARE @WFFinished BIT=0
	
	DECLARE @CostContRepDTC INT= 
	(SELECT DocumentTypeCode FROM Docs_Infos WHERE DocumentTypeName='WSI_SUCF_CostContractReport')
	
	 --درصورتي كه گردش تمام شده
	 IF @IsCompile=0
		SELECT @DocumentCode=CompileDC,@WFFinished=1 FROM wfi_PoolInstances WHERE MainDC= @DocumentCode AND DTC= @CostContRepDTC		

	---------------------------------------------------------------------------------------------
	--كد گردش جاري							
	DECLARE @CurrentWFLetter nvarchar(20)=
	
	(Select WorkflowLetter from dbo.wfi_PoolInstances P
		inner join wfi_WorkflowInstances WI on P.PoolInstanceCode=WI.PoolInstanceCode 
			inner join dbo.wfd_Workflows W on WI.WorkflowCode=W.WorkflowCode
				 where DTC=@CostContRepDTC and CompileDC=@DocumentCode and WFFinished=@WFFinished)	
	----------------------------------------------------------------------------------------------
		DECLARE @CompanyNameFltr NVARCHAR(20) --فیلتر نام واحد فناور
			,@BuildingNameFltr NVARCHAR(20)  -- فیلتر نام ساختمان
			,@DisplayChangesCourse BIT --نمايش گزارش واحدهاي فناوري كه در بازه انتخابي تغيير دوره داشته اند
			,@SortOF NVARCHAR(50) --مرتب سازي بر اساس
			,@SortType NVARCHAR(20) --نحوه مرتب سازي
			,@EarlierDate DATE  --تاريخ ابتداي بازه
			,@EndDateFltr DATE  --تاريخ انتهاي بازه
			,@SqlCommand NVARCHAR(MAX)
			,@NoSortOF NVARCHAR(50)
			,@ET nvarchar(20) --اداری یا تاسیسات
			 
	--============================================================================================
	IF @CurrentWFLetter='SUCF28' --گزارش مبالغ قراردادهاي اسكان و استقرار
	BEGIN
				 
	DECLARE @CompanyName NVARCHAR(20)
			,@BuildingName NVARCHAR(20)
			,@EndDateFilter DATE
			,@SqlHrader NVARCHAR(MAX)
			,@SqlResult NVARCHAR(MAX)
			,@CostContractReport NVARCHAR(MAX)

			
	SELECT 
		@CompanyName=SUCF28H01_CompanyName
		,@BuildingName =SUCF28H01_BuildingName
		,@DisplayChangesCourse=SUCF28H01_DisplayChangesCourse
		,@SortOF=SUCF28H01_SortOF
		,@SortType =SUCF28H01_SortType
		,@EarlierDate =SUCF28H01_EarlierDate
		,@EndDateFilter =SUCF28H01_EndDate
	FROM WSI_SUCF_CostContractReport_Compile WHERE DocumentCode=@DocumentCode
	
	IF(@SortOF='RERC23H01_FinancialCode')
		SET @NoSortOF='1'
		
	IF(@SortOF='Cost')
		SET @NoSortOF='11'
		
	IF(@SortOF='AdmissionPeriod')
		SET @NoSortOF='3'
				
		
	DECLARE @DTC_Contracts INT =
		(SELECT DocumentTypeCode FROM Docs_Infos WHERE DocumentTypeName='WSI_STOO_Contracts')--WSI_STOO_Contracts
	
	DECLARE @SUCF07 INT =
		(SELECT WorkflowCode FROM wfd_Workflows WHERE WorkflowLetter='SUCF07')
		
	DECLARE @SUCF17 INT=
		(SELECT WorkflowCode FROM wfd_Workflows WHERE WorkflowLetter='SUCF17')	
		
	DECLARE @SUCF26 INT=
		(SELECT WorkflowCode FROM wfd_Workflows WHERE WorkflowLetter='SUCF26')
		
	DECLARE @SUCF27 INT=
		(SELECT WorkflowCode FROM wfd_Workflows WHERE WorkflowLetter='SUCF27')
		
	DECLARE @SUCF31 INT=
		(SELECT WorkflowCode FROM wfd_Workflows WHERE WorkflowLetter='SUCF31')
		
	DECLARE @SUCF32 INT=
		(SELECT WorkflowCode FROM wfd_Workflows WHERE WorkflowLetter='SUCF32')
		
	DECLARE @SUCF37 INT=
		(SELECT WorkflowCode FROM wfd_Workflows WHERE WorkflowLetter='SUCF37')	
		
	DECLARE @SUCF38 INT=
		(SELECT WorkflowCode FROM wfd_Workflows WHERE WorkflowLetter='SUCF38')							
	
	
		
	IF (@SortOF= '--------' OR @SortOF='-1')
	BEGIN
		SELECT  N'نحوه مرتب سازي را انتخاب نمایید'		
		RETURN
	END

	SET @SqlHrader =N'SELECT  N''کد مالی'',N'' نام واحد فناور'',N''دوره پذيرش'',N''ساختمان'',N''شماره فضاها''
						,N''تاريخ شروع قرارداد 1''
						,N''تاريخ پايان قرارداد 1'',N'' تاريخ شروع قرارداد2'',N'' تاريخ پايان قرارداد 2''
						,N''مبلغ1(ريال)'' 
						,N''مبلغ 2(ريال)''
						,N''مبلغ تاسیسات 1''
						,N''مبلغ تاسیسات 2''
						,N''مبلغ كل در بازه انتخابي(ريال)''
						,N''مبلغ كل تاسیسات در بازه انتخابي(ريال)''
						,N''مجموع مبلغ كل با درصد تاسیسات در بازه انتخابي(ريال)''
						'

	SET @SqlCommand= N'SELECT DISTINCT ISNULL(CAST(RERC23H01_FinancialCode AS NVARCHAR(50)),N''----'')
					,TDOO26H01_CompanyName
					,RERC23H01_UpdatePeriod
					,STOO10H01_AutoBuild
					,STOO10H01_SpaceCode
					,DBO.getShamsiDate(STOO10H01_StartDate)
					,DBO.getShamsiDate(STOO10H01_EndDate)
					,(SELECT CASE 
						WHEN STOO10H01_StartDate2 <>''1900-01-01'' THEN DBO.getShamsiDate(STOO10H01_StartDate2)
						WHEN STOO10H01_StartDate2 =''1900-01-01'' THEN ''''
					END)
					,(SELECT CASE 
						WHEN STOO10H01_EndDate2 <>''1900-01-01'' THEN DBO.getShamsiDate(STOO10H01_EndDate2)
						WHEN STOO10H01_EndDate2 =''1900-01-01'' THEN ''''
					END)
					,ISNULL(DBO.ssSeparate(STOO10H01_ContractAmount),0)
					,ISNULL(DBO.ssSeparate(STOO10H01_ContractAmount2),0)
					,ISNULL(DBO.ssSeparate(STOO10H01_InsSum1),0)
					,ISNULL(DBO.ssSeparate(STOO10H01_InsSum2),0)
			
					,CAST((dbo.SUCF28_ContractAmount
					('''+CAST(@EarlierDate AS NVARCHAR(50))+''''
					+','''+CAST(@EndDateFilter AS NVARCHAR(50))+''''+',STOO10H01_StartDate
					,STOO10H01_EndDate,STOO10H01_ContractAmount
					,STOO10H01_StartDate2,STOO10H01_EndDate2
					,STOO10H01_ContractAmount2 ,STOO10H01_TerminationDate))AS NVARCHAR(100))
					
					,CAST((dbo.SUCF28_ContractAmount
					('''+CAST(@EarlierDate AS NVARCHAR(50))+''''
					+','''+CAST(@EndDateFilter AS NVARCHAR(50))+''''+',STOO10H01_StartDate
					,STOO10H01_EndDate,STOO10H01_InsSum1
					,STOO10H01_StartDate2,STOO10H01_EndDate2
					,STOO10H01_InsSum2 , STOO10H01_TerminationDate))AS NVARCHAR(100))
					
					,CAST(((dbo.SUCF28_ContractAmount
					('''+CAST(@EarlierDate AS NVARCHAR(50))+''''
					+','''+CAST(@EndDateFilter AS NVARCHAR(50))+''''+',STOO10H01_StartDate
					,STOO10H01_EndDate,STOO10H01_ContractAmount
					,STOO10H01_StartDate2,STOO10H01_EndDate2
					,STOO10H01_ContractAmount2 ,STOO10H01_TerminationDate)))
					
					+(((dbo.SUCF28_ContractAmount
					('''+CAST(@EarlierDate AS NVARCHAR(50))+''''
					+','''+CAST(@EndDateFilter AS NVARCHAR(50))+''''+',STOO10H01_StartDate
					,STOO10H01_EndDate,STOO10H01_InsSum1
					,STOO10H01_StartDate2,STOO10H01_EndDate2
					,STOO10H01_InsSum2,STOO10H01_TerminationDate))))AS NVARCHAR(100))
										
					FROM WSI_STOO_Contracts Cont
					INNER JOIN WSI_RERC_AdmissionPermission ON 
					RERC23H01_CompanyName=STOO10H01_CompanyNameSelection 
					INNER JOIN WSI_TDOO_Company CO ON 
					CO.DocumentCode=STOO10H01_CompanyNameSelection 
					INNER JOIN wfi_WorkflowInstances WI ON
					Cont.DocumentCode=WI.MainDC
					WHERE 
						(STOO10H01_Dissuasion=0 OR STOO10H01_Dissuasion IS NULL)   
						AND (
							(STOO10H01_TerminationContract=0 OR STOO10H01_TerminationContract IS NULL)
							OR(STOO10H01_TerminationContract=1 
								AND (STOO10H01_TerminationDate> '''+CAST(@EarlierDate AS NVARCHAR(50))+'''
									OR STOO10H01_TerminationDate='''+CAST(@EarlierDate AS NVARCHAR(50))+'''))
							)
						AND (RERC23H01_UpdatePeriod IS NOT NULL)	
						AND (STOO10H01_Amendmentsto=0 OR STOO10H01_Amendmentsto IS NULL)
						AND (WorkflowCode = '''+ CAST(@SUCF07 AS NVARCHAR(50))+'''
							 OR WorkflowCode = '''+ CAST(@SUCF17 AS NVARCHAR(50))+'''
							 OR WorkflowCode = '''+ CAST(@SUCF26 AS NVARCHAR(50))+'''
							 OR WorkflowCode = '''+ CAST(@SUCF31 AS NVARCHAR(50))+'''
							 OR WorkflowCode = '''+ CAST(@SUCF32 AS NVARCHAR(50))+'''
							 OR WorkflowCode = '''+ CAST(@SUCF37 AS NVARCHAR(50))+'''
							 OR WorkflowCode = '''+ CAST(@SUCF38 AS NVARCHAR(50))+'''
							 OR WorkflowCode = '''+ CAST(@SUCF27 AS NVARCHAR(50))+''''
							 
							  
	IF(@CompanyName='-1') --نام واحد فناور انتخاب نشده و گزارش كلي است
	BEGIN
		IF(@BuildingName='-1' OR @BuildingName IS NULL OR @BuildingName='') -- ساختمان هم انتخاب نشده است
		BEGIN
			IF (@DisplayChangesCourse=0)--شركت تغيير دوره نداشته است
			BEGIN 

				SET @SqlCommand=@SqlCommand +N'
					 )AND (((
						(STOO10H01_EndDate>'''+CAST(@EndDateFilter AS NVARCHAR(50))+'''
							OR STOO10H01_EndDate='''+CAST(@EndDateFilter AS NVARCHAR(50))+''')'
							
					+'AND  (STOO10H01_StartDate< '''+CAST(@EarlierDate AS NVARCHAR(50))+'''
							OR STOO10H01_StartDate= '''+CAST(@EarlierDate AS NVARCHAR(50))+''')'
					+')'
					+' OR(STOO10H01_StartDate BETWEEN'''+CAST(@EarlierDate AS NVARCHAR(50))+''''
					+' AND '''+ CAST(@EndDateFilter AS NVARCHAR(50))+''''+')) OR 
					(
						(STOO10H01_EndDate2>'''+CAST(@EndDateFilter AS NVARCHAR(50))+'''
						OR STOO10H01_EndDate2='''+CAST(@EndDateFilter AS NVARCHAR(50))+''')'
					+'AND  
						(STOO10H01_StartDate2< '''+CAST(@EarlierDate AS NVARCHAR(50))+'''
						OR STOO10H01_StartDate2= '''+CAST(@EarlierDate AS NVARCHAR(50))+''')'+')'
					+' OR(STOO10H01_StartDate2 BETWEEN'''+CAST(@EarlierDate AS NVARCHAR(50))+''''
					+' AND '''+ CAST(@EndDateFilter AS NVARCHAR(50))+''''+'))'
					+' ORDER BY '+ @NoSortOF+' ' + @SortType

				SET @SqlResult= (@SqlHrader+ @SqlCommand )
				EXEC (@SqlResult) 
--SELECT @SqlCommand
			END --@DisplayChangesCourse=0


--@CompanyName='-1' AND @BuildingName='-1'
			IF (@DisplayChangesCourse=1)--شركت تغيير دوره داشته است،تاريخ شروع2 قرارداد در بازه است
			BEGIN
				SET @SqlCommand=@SqlCommand +'			
					 )AND (( 
					STOO10H01_StartDate2 BETWEEN'''
					+CAST(@EarlierDate AS NVARCHAR(50))+''''
					+' AND '''+ CAST(@EndDateFilter AS NVARCHAR(50))+''''+'))'
					+' ORDER BY '+ @NoSortOF+' ' + @SortType

				SET @SqlResult= (@SqlHrader+ @SqlCommand )
				EXEC (@SqlResult)
			END	 --@DisplayChangesCourse=1
						
		END --@BuildingName='-1'


-- نام ساختمان انتخاب شده است
		IF(@BuildingName<>'-1'AND @BuildingName IS NOT NULL AND @BuildingName<>'')--ساختمان انتخاب شده
		BEGIN
			IF(@DisplayChangesCourse=0)
			BEGIN
				SET @SqlCommand=@SqlCommand +'
					 )AND ((((STOO10H01_EndDate>'''+CAST(@EndDateFilter AS NVARCHAR(50))+''''
					+'AND  STOO10H01_StartDate< '''+CAST(@EarlierDate AS NVARCHAR(50))+''''+')'
					+' OR(STOO10H01_StartDate BETWEEN'''+CAST(@EarlierDate AS NVARCHAR(50))+''''
					+' AND '''+ CAST(@EndDateFilter AS NVARCHAR(50))+''''+')) OR 
					(STOO10H01_EndDate2>'''+CAST(@EndDateFilter AS NVARCHAR(50))+''''
					+'AND  STOO10H01_StartDate2< '''+CAST(@EarlierDate AS NVARCHAR(50))+''''+')'
					+' OR(STOO10H01_StartDate2 BETWEEN'''+CAST(@EarlierDate AS NVARCHAR(50))+''''
					+' AND '''+ CAST(@EndDateFilter AS NVARCHAR(50))+''''+')))'
					+' AND STOO10H01_BuildingName ='''+@BuildingName +''''
					+' ORDER BY '+ @NoSortOF+' ' + @SortType

				SET @SqlResult= (@SqlHrader+ @SqlCommand )
				EXEC (@SqlResult)
			END
			
			IF(@DisplayChangesCourse=1)
			BEGIN
				SET @SqlCommand=@SqlCommand +'		
					 )AND ((((STOO10H01_EndDate>'''+CAST(@EndDateFilter AS NVARCHAR(50))+''''
					+'AND  STOO10H01_StartDate< '''+CAST(@EarlierDate AS NVARCHAR(50))+''''+')'
					+' OR(STOO10H01_StartDate BETWEEN'''+CAST(@EarlierDate AS NVARCHAR(50))+''''
					+' AND '''+ CAST(@EndDateFilter AS NVARCHAR(50))+''''+')) OR 
					(STOO10H01_EndDate2>'''+CAST(@EndDateFilter AS NVARCHAR(50))+''''
					+'AND  STOO10H01_StartDate2< '''+CAST(@EarlierDate AS NVARCHAR(50))+''''+')'
					+' OR(STOO10H01_StartDate2 BETWEEN'''+CAST(@EarlierDate AS NVARCHAR(50))+''''
					+' AND '''+ CAST(@EndDateFilter AS NVARCHAR(50))+''''+'))'
					+' AND STOO10H01_BuildingName ='''+@BuildingName +''''
					+' AND (STOO10H01_StartDate2 BETWEEN'''+CAST(@EarlierDate AS NVARCHAR(50))+''''
					+' AND '''+ CAST(@EndDateFilter AS NVARCHAR(50))+'''))'
					
					+' ORDER BY '+ @NoSortOF+' ' + @SortType

				SET @SqlResult= (@SqlHrader+ @SqlCommand )
				EXEC (@SqlResult)
			END			

		END	--@BuildingName<>'-1'	

	END --@CompanyName='-1'
	
	
	IF(@CompanyName <>'-1') --نام واحد فناور انتخاب شده
	BEGIN
		SET @SqlCommand=@SqlCommand +'	
			
			 )AND ((((STOO10H01_EndDate>'''+CAST(@EndDateFilter AS NVARCHAR(50))+''''
			+'AND  STOO10H01_StartDate< '''+CAST(@EarlierDate AS NVARCHAR(50))+''''+')'
			+' OR(STOO10H01_StartDate BETWEEN'''+CAST(@EarlierDate AS NVARCHAR(50))+''''
			+' AND '''+ CAST(@EndDateFilter AS NVARCHAR(50))+''''+')) OR 
			(STOO10H01_EndDate2>'''+CAST(@EndDateFilter AS NVARCHAR(50))+''''
			+'AND  STOO10H01_StartDate2< '''+CAST(@EarlierDate AS NVARCHAR(50))+''''+')'
			+' OR(STOO10H01_StartDate2 BETWEEN'''+CAST(@EarlierDate AS NVARCHAR(50))+''''
			+' AND '''+ CAST(@EndDateFilter AS NVARCHAR(50))+''''+')))'
			+' AND STOO10H01_CompanyNameSelection ='''+@CompanyName +''''
			+' ORDER BY '+ @NoSortOF+' ' + @SortType

		SET @SqlResult= (@SqlHrader+ @SqlCommand )
		EXEC (@SqlResult)
	END --@CompanyName <>'-1'
--SELECT @SqlCommand
   END
	--============================================================================================
  
  IF @CurrentWFLetter='SUCF50' --گزارش شارژ ماهانه واحدهاي فناوري
   BEGIN
	 --شماره جدول تعرفه فضا  
	DECLARE @DTC_SpaceTarrif int= 
	(select DocumentTypeCode FROM Docs_Infos WHERE DocumentTypeName='WSI_SUCF_SpaceTarrif')
	-----------------------------------------------------------------------------------------
	 --شماره جدول تعرفه تصويب شده انواع فضاها  
	DECLARE @DTC_TariffAproved int= 
	(select DocumentTypeCode FROM Docs_Infos WHERE DocumentTypeName='WSI_SUCF_TariffAproved')
	-----------------------------------------------------------------------------------------

    DECLARE @MainTable table(ReportDATE nvarchar(20),Functor nvarchar(30),Rtrn nvarchar(30),CompanyID NVARCHAR(30),CompanyName nvarchar(max)
     ,OLDFinancialCode nvarchar(30),NEWFinancialCode nvarchar(30),BuildingName nvarchar(max),BuildingCode nvarchar(30)
      ,S1 nvarchar(30),S2 nvarchar(30),SpaceType nvarchar(50),Price int,DiscountPrice int ,Discount nvarchar(30))
    
    DECLARE @TemporaryTemp table(FieldName nvarchar(10),CompanyID int,CompanyName nvarchar(max),FinancialCode nvarchar(10)
		    ,NewFinancialCode nvarchar(20),BuildingCode nvarchar(3),BuildingName nvarchar(max)
             ,ContractType nvarchar(50),SpaceCode nvarchar(10),SpaceType nvarchar(50),Price float,DiscountPrice float,OI NVARCHAR(20))
    
    --جدول براي محاسبه ي ديكرد تحويل فضا                            
    DECLARE @DelayTemp table(SpaceCode nvarchar(10),SpaceType nvarchar(50),S2 nvarchar(30),Price float)			
    
	SELECT 
		 @CompanyNameFltr=SUCF28H01_CompanyName
		,@BuildingNameFltr =SUCF28H01_BuildingName
		,@DisplayChangesCourse=SUCF28H01_DisplayChangesCourse
		,@SortOF=SUCF28H01_SortOF
		,@SortType =SUCF28H01_SortType
		,@EarlierDate =SUCF28H01_EarlierDate
		,@EndDateFltr =SUCF28H01_EndDate
	FROM WSI_SUCF_CostContractReport_Compile WHERE DocumentCode=@DocumentCode	
	
	 DECLARE @SpaceType nvarchar(2)
	 DECLARE @TotalDiscountCost float
	 DECLARE @TotalCost float	    
	 DECLARE @SpaceTypeTBL table(SpaceType nvarchar(2))
	    
					
    DECLARE @DCContracts int

	DECLARE @DCTemp TABLE (DocumentCode int) --جدول برای نگهداری دی سی ها
	INSERT INTO @DCTemp -- قراردادهایی که در بازه ی مشخص شده باشند
	
	SELECT DocumentCode FROM WSI_STOO_Contracts WHERE 
	((STOO10H01_StartDate>=@EarlierDate and STOO10H01_StartDate<=@EndDateFltr) OR
	 (STOO10H01_StartDate2<>'' and STOO10H01_StartDate2<>'1900-01-01' and STOO10H01_StartDate2<>'Jan  1 1900 12:00AM' and STOO10H01_StartDate2 IS NOT NULL
	  and STOO10H01_StartDate2>=@EarlierDate and STOO10H01_StartDate2<=@EndDateFltr) OR
	  (STOO10H01_EndDate>=@EarlierDate and STOO10H01_EndDate<=@EndDateFltr) OR 
	   (STOO10H01_EndDate2<>'' and STOO10H01_EndDate2<>'1900-01-01' and STOO10H01_EndDate2<>'Jan  1 1900 12:00AM' and STOO10H01_EndDate2 IS NOT NULL
	     and STOO10H01_EndDate2>=@EarlierDate and STOO10H01_EndDate2<=@EndDateFltr) OR
	      (STOO10H01_StartDate<=@EarlierDate and STOO10H01_EndDate>=@EndDateFltr) OR
	       (STOO10H01_StartDate2<=@EarlierDate and STOO10H01_EndDate2>=@EndDateFltr)) AND 	     
	       ((@CompanyNameFltr<>'-1' and STOO10H01_CompanyNameSelection = @CompanyNameFltr) OR --فیلتر نام واحد فناور
	        (@CompanyNameFltr='-1' and STOO10H01_CompanyNameSelection IN (SELECT STOO10H01_CompanyNameSelection FROM WSI_STOO_Contracts)))AND
	         ((@BuildingNameFltr<>'-1' and STOO10H01_BuildingName=@BuildingNameFltr)OR --فیلتر نام ساختمان
	          (@BuildingNameFltr='-1' and STOO10H01_BuildingName IN (SELECT STOO10H01_BuildingName FROM WSI_STOO_Contracts)))	          
	           AND STOO10H01_ManagerCheckResult<>'Cancel'--انصراف واحد فناور
	            AND STOO10H01_PreiodCode<>'PI'  -- هسته ها در گزارش نيايند
	            --and STOO10H01_CompanyNameSelection=336 
	            --and DocumentCode IN(89,78)
	            UNION -- قراردادهایی که تاریخ پایان آنها گذشته است
    SELECT DocumentCode FROM WSI_STOO_Contracts WHERE
     ((STOO10H01_EndDate2<>'' and STOO10H01_EndDate2<>'1900-01-01' and STOO10H01_EndDate2<>'Jan  1 1900 12:00AM' and STOO10H01_EndDate2 IS NOT NULL
	  and STOO10H01_EndDate2<@EarlierDate) OR 
	  ((STOO10H01_EndDate2='' or STOO10H01_EndDate2='1900-01-01' or STOO10H01_EndDate2='Jan  1 1900 12:00AM' or STOO10H01_EndDate2 IS NULL)
	   and STOO10H01_endDate<@EarlierDate))AND 	     
       ((@CompanyNameFltr<>'-1' and STOO10H01_CompanyNameSelection = @CompanyNameFltr) OR --فیلتر نام واحد فناور
        (@CompanyNameFltr='-1' and STOO10H01_CompanyNameSelection IN (SELECT STOO10H01_CompanyNameSelection FROM WSI_STOO_Contracts)))AND
         ((@BuildingNameFltr<>'-1' and STOO10H01_BuildingName=@BuildingNameFltr)OR --فیلتر نام ساختمان
          (@BuildingNameFltr='-1' and STOO10H01_BuildingName IN (SELECT STOO10H01_BuildingName FROM WSI_STOO_Contracts)))	          
           AND STOO10H01_ManagerCheckResult<>'Cancel'--انصراف واحد فناور
	        AND STOO10H01_PreiodCode<>'PI'  -- هسته ها در گزارش نيايند
	        --and STOO10H01_CompanyNameSelection=336 
	        --and DocumentCode IN(89,78)
    
 	--SELECT @EarlierDate =DBO.getShamsiDate(@EarlierDate)
	
  --  SELECT @EndDateFltr =DBO.getShamsiDate(@EndDateFltr) 
	               
	--SELECT * FROM @DCTemp
	WHILE (SELECT COUNT(*) FROM @DCTemp)>0
	BEGIN --***
	    

	    DELETE @TemporaryTemp  --جدول را در ابتدای هر  رکورد از قرارداد خالی می کنیم
        
		SELECT top 1 @DCContracts =DocumentCode FROM @DCTemp
		
		DECLARE @CompanyID int
		DECLARE @BuildingCode nvarchar(3)
		DECLARE @OI nvarchar(20) --اداری یا تاسیسات
		DECLARE @Price int 
		DECLARE @DiscountPrice int
		DECLARE @Discount int
		DECLARE @Cost2 nvarchar(20)=''
		DECLARE @StartDate Date--تاريخ شروع قرارداد
		DECLARE @StartDate2 Date--تاريخ شروع قرارداد2
		DECLARE @EndDate Date--تاريخ پایان قرارداد
		DECLARE @EndDate2 Date--تاريخ پایان قرارداد2
		DECLARE @Amendmentsto bit --بیت الحاقیه دارد
		DECLARE @TerminationContract bit -- بین فسخ شد
		DECLARE @TerminationDate Date--تاريخ فسخ یا الحاقیه قرارداد

		select
		  @CompanyID= STOO10H01_CompanyNameSelection,		
		  @Cost2= STOO10H01_ContractAmount2,
		  @StartDate=STOO10H01_StartDate,
		  @StartDate2=STOO10H01_StartDate2,
	 	  @EndDate=STOO10H01_EndDate,
	      @EndDate2=STOO10H01_EndDate2,
	      @Amendmentsto=STOO10H01_Amendmentsto,
	      @TerminationContract=STOO10H01_TerminationContract,
	      @TerminationDate=ISNULL(STOO10H01_TerminationDate,'')	         
			from WSI_STOO_Contracts where DocumentCode = @DCContracts

	 	IF @Amendmentsto=1 OR @TerminationContract=1 --اگر قرارداد فسخ شده باشد یا الحاقیه داشته باشد
	 	begin --تاریخ پایان قراردادها را تاریخ فسخ یا الحاقیه در نظر میگیریم
	      if @TerminationDate <= @EndDate  
	         select @EndDate=@TerminationDate,@Cost2='' -- مبلغ دو را خالی میکنیم چون دیگر در آن بازه ی مبلغ دو قرارداد فسخ شده و محاسبه ی آن نیازی نیس
	      else if @TerminationDate <= @EndDate2 
	         select @EndDate2=@TerminationDate
	    end	   	  
	   	 		   	 	 	
		DECLARE @Divided INT
		DECLARE @Divided2 INT		
		DECLARE @Mount INT
		DECLARE @MountCount INT
		DECLARE @DayCount INT
		DECLARE @DayCount2 INT
		
        --قراردادهایی که تاریخ پایان آنها گذشته و فسخ نشده باشد الحاقیه هم نخورده باشد
        --اگر فسخ شده يا الحاقيه خورده قبلا فضاها را پس داده و نيازي به محاسبه ي ديركرد نيست
        IF ((@EndDate2<>'' and @EndDate2<>'1900-01-01' and @EndDate2<>'Jan  1 1900 12:00AM' and @EndDate2 IS NOT NULL
	     and @EndDate2<@EarlierDate) or 
	      ((@EndDate2='' or @EndDate2='1900-01-01' or @EndDate2='Jan  1 1900 12:00AM' or @EndDate2 IS NULL)
	        and @EndDate<@EarlierDate)) 
	         AND (@Amendmentsto=0 or @Amendmentsto IS NULL)
	          AND (@TerminationContract=0 or @TerminationContract IS NULL)
		BEGIN
		    DECLARE @SpcCode nvarchar(10)
		    
		 	INSERT INTO @TemporaryTemp 
		      EXEC [dbo].[CostTable] @FieldName='Cost',@DocumentCode=@DCContracts
		    
		    select top 1 @BuildingCode=BuildingCode from @TemporaryTemp
		  ---------------------------------------------------------------------		   		
		    INSERT INTO @DelayTemp
		    	SELECT SpaceCode,SpaceType,OI,Price FROM @TemporaryTemp  
		    	 
			WHILE (SELECT COUNT(*) FROM @DelayTemp)>0
			  BEGIN
				SELECT TOP 1 @SpcCode=SpaceCode							
							  FROM @DelayTemp   
							   
			     --اگر عودت فضا وجود دارد برای این فضا دیرکرد محاسبه نشود
				IF EXISTS (SELECT * FROM WSI_SUCF_ChangeSpace_Compile WHERE 
				 SUCF29H01_CompanyUserCode=@CompanyID AND SUCF29H01_BuildingSelection=@BuildingCode 
				  AND SUCF29H01_IntendedReturnSpace_SubFields_XML LIKE '%"'+@SpcCode+'"%'
					AND SUCF29H01_EvacuationPermission=1 and SUCF29H01_ReturnDate<=@EarlierDate) 
			    --اگر روی همین فضا دوباره قرارداد فعال دارد نیازی به عودت نیس و دیرکرد برایش محاسبه نمی شود
				OR EXISTS (SELECT DocumentCode FROM WSI_STOO_Contracts WHERE 
				((STOO10H01_StartDate>=@EarlierDate and STOO10H01_StartDate<=@EndDateFltr) OR
				 (STOO10H01_StartDate2<>'' and STOO10H01_StartDate2<>'1900-01-01' 
				   AND STOO10H01_StartDate2<>'Jan  1 1900 12:00AM' and STOO10H01_StartDate2 IS NOT NULL
					AND STOO10H01_StartDate2>=@EarlierDate and STOO10H01_StartDate2<=@EndDateFltr) OR
					 (STOO10H01_EndDate>=@EarlierDate and STOO10H01_EndDate<=@EndDateFltr) OR 
					   (STOO10H01_EndDate2<>'' and STOO10H01_EndDate2<>'1900-01-01' 
						AND STOO10H01_EndDate2<>'Jan  1 1900 12:00AM' and STOO10H01_EndDate2 IS NOT NULL
						 and STOO10H01_EndDate2>=@EarlierDate and STOO10H01_EndDate2<=@EndDateFltr) OR
						  (STOO10H01_StartDate<=@EarlierDate and STOO10H01_EndDate>=@EndDateFltr) OR
						   (STOO10H01_StartDate2<=@EarlierDate and STOO10H01_EndDate2>=@EndDateFltr)) AND 	     
						   (STOO10H01_CompanyNameSelection = @CompanyID) AND  --فیلتر نام واحد فناور
							(STOO10H01_BuildingName=@BuildingCode) --فیلتر نام ساختمان							  	          
							   AND STOO10H01_ManagerCheckResult<>'Cancel'--انصراف واحد فناور
								AND STOO10H01_PreiodCode<>'PI'  -- هسته ها در گزارش نيايند
								 AND STOO10H01_spacecode LIKE '%'+@SpcCode+'%')
					
                    DELETE FROM @TemporaryTemp WHERE SpaceCode=@SpcCode
                    
                DELETE FROM @DelayTemp WHERE SpaceCode=@SpcCode

              END
		  ---------------------------------------------------------------------		   
		     INSERT INTO @DelayTemp
		    	SELECT SpaceCode,SpaceType,OI,Price FROM @TemporaryTemp    
		    	--select * from @TemporaryTemp    
		    	
		     UPDATE @TemporaryTemp set DiscountPrice=0,Price=0
        					
		END
        --======================================================================================================
		IF (@StartDate>=@EarlierDate and @StartDate<=@EndDateFltr) OR		
			  (@EndDate>=@EarlierDate and @EndDate<=@EndDateFltr) OR
			    (@StartDate<=@EarlierDate and @EndDate>=@EndDateFltr) 
		BEGIN
		   	 
		 	INSERT INTO @TemporaryTemp 
		      EXEC [dbo].[CostTable] @FieldName='Cost',@DocumentCode=@DCContracts
		      
		  ---------------------------------------------------------------------
		    --اگر فسخ شده يا الحاقيه خورده قبلا فضاها را پس داده و نيازي به محاسبه ي ديركرد نيست
		    --و تاريخ پايان قرارداد قبل از بازه ي گزارش گيري است
		    IF (@Amendmentsto=0 or @Amendmentsto IS NULL) AND 
		      (@TerminationContract=0 or @TerminationContract IS NULL)
		       AND @EndDate < @EndDateFltr and 
		        ((@EndDate2<>'' and @EndDate2<>'1900-01-01' 
		         and @EndDate2<>'Jan  1 1900 12:00AM' and @EndDate2 IS NOT NULL
		          and @EndDate2 < @EndDateFltr) OR (@EndDate2='' or @EndDate2='1900-01-01' 
		           or @EndDate2='Jan  1 1900 12:00AM' or @EndDate2 IS NULL))		       
		     
		    	INSERT INTO @DelayTemp
		    	 SELECT SpaceCode,SpaceType,OI,Price FROM @TemporaryTemp   
		    	 
		    	 
		    	 --select * from @DelayTemp		    	 
		  ---------------------------------------------------------------------
		  
			IF @StartDate<@EarlierDate
			 SET @StartDate=@EarlierDate
			 
			IF @EndDate>@EndDateFltr
			 SET @EndDate=@EndDateFltr	
			 
			 
			IF SUBSTRING(DBO.getShamsiDate(@EndDate),9,2)>= SUBSTRING(DBO.getShamsiDate(@StartDate),9,2)
			--DATEPART(DAY,@EndDate) > DATEPART(DAY,@StartDate)	
			BEGIN			
			  SELECT @Mount=SUBSTRING(DBO.getShamsiDate(@EndDate),6,2)
			  --=DATEPART(M,@EndDate)
			  SELECT @DayCount=cast(SUBSTRING(DBO.getShamsiDate(@EndDate),9,2) as Int)- cast(SUBSTRING(DBO.getShamsiDate(@StartDate),9,2) as Int)+1
			  --=DATEPART(DAY,@EndDate)-DATEPART(DAY,@StartDate)
			  SELECT @MountCount=@Mount-cast(SUBSTRING(DBO.getShamsiDate(@StartDate),6,2) as Int)
			  --=@Mount-DATEPART(M,@StartDate)
			  
			  IF @Mount<=6
			   SET @Divided=31
			  ELSE IF @Mount=12
			   SET @Divided=29
			  ELSE IF @Mount>6
			   SET @Divided=30		   		   
			   
			  UPDATE @TemporaryTemp SET DiscountPrice=ROUND(((DiscountPrice*@MountCount)+((@DayCount*(DiscountPrice/@Divided)))),0),
			   Price=ROUND(((Price*@MountCount)+((@DayCount*(Price/@Divided)))),0)
				  WHERE FieldName='Cost'
			END
					  
			ELSE IF SUBSTRING(DBO.getShamsiDate(@EndDate),9,2)< SUBSTRING(DBO.getShamsiDate(@StartDate),9,2)
			--DATEPART(DAY,@EndDate) < DATEPART(DAY,@StartDate)
			 BEGIN				
			  SELECT @Mount=cast(SUBSTRING(DBO.getShamsiDate(@EndDate),6,2)as Int)-1
			  --=DATEPART(M,@EndDate)-1
			  		  
			  SELECT @DayCount=SUBSTRING(DBO.getShamsiDate(@EndDate),9,2)
			  --=DATEPART(DAY,@EndDate)
			  
			  SELECT @MountCount=@Mount-cast(SUBSTRING(DBO.getShamsiDate(@StartDate),6,2) as Int)
			  --=@Mount-DATEPART(M,@StartDate)
			  
			  IF @Mount<=6
			   SET @Divided=31
			  ELSE IF @Mount=12
			   SET @Divided=29
			  ELSE IF @Mount>6
			   SET @Divided=30		   		   

			  IF (@Mount-1) = 0
			   SET @Divided2=31
			  ELSE IF (@Mount-1)<=6
			   SET @Divided2=29
			  ELSE IF (@Mount-1)>6
			   SET @Divided2=30	

			  SELECT @DayCount2=@Divided2-cast(SUBSTRING(DBO.getShamsiDate(@StartDate),9,2) as Int)
			  --=@Divided2-DATEPART(DAY,@StartDate)

			   UPDATE @TemporaryTemp SET
				DiscountPrice=ROUND(((DiscountPrice*@MountCount)+((@DayCount*(DiscountPrice/@Divided)))+((@DayCount2*(DiscountPrice/@Divided2)))),0),
				  Price=ROUND(((Price*@MountCount)+((@DayCount*(Price/@Divided)))+((@DayCount2*(Price/@Divided2)))),0)
				  WHERE FieldName='Cost'		      		      		      
			END	
	    END	
	    
        --======================================================================================================
	    
		IF @Cost2<>'' AND @Cost2 IS NOT NULL AND
		 ((@StartDate2>=@EarlierDate and @StartDate2<=@EndDateFltr) OR		
			  (@EndDate2>=@EarlierDate and @EndDate2<=@EndDateFltr)OR
			    (@StartDate2<=@EarlierDate and @EndDate2>=@EndDateFltr)) 
		BEGIN	
			INSERT INTO @TemporaryTemp 
		       EXEC [dbo].[CostTable] @FieldName='Cost2',@DocumentCode=@DCContracts				
		  
		  ---------------------------------------------------------------------
		  	--اگر فسخ شده يا الحاقيه خورده قبلا فضاها را پس داده و نيازي به محاسبه ي ديركرد نيست
		  	--اگر در حلقه ي اولي اين اينسرت انجام شده نيازي به انجام دوباره نيست
		    IF (@Amendmentsto=0 or @Amendmentsto IS NULL) AND 
		      (@TerminationContract=0 or @TerminationContract IS NULL)
		       AND (SELECT COUNT(*) FROM @DelayTemp)=0
		         AND @EndDate2<@EndDateFltr
		       
		    	INSERT INTO @DelayTemp
		    	 SELECT SpaceCode,SpaceType,OI,Price FROM @TemporaryTemp   
		  ---------------------------------------------------------------------
		 
			IF @StartDate2<@EarlierDate
			 SET @StartDate2=@EarlierDate
			 
			IF @EndDate2>@EndDateFltr
			 SET @EndDate2=@EndDateFltr	
			
			
	IF SUBSTRING(DBO.getShamsiDate(@EndDate2),9,2)>= SUBSTRING(DBO.getShamsiDate(@StartDate2),9,2)
			BEGIN			
			  SELECT @Mount=SUBSTRING(DBO.getShamsiDate(@EndDate2),6,2)
			  SELECT @DayCount=cast(SUBSTRING(DBO.getShamsiDate(@EndDate2),9,2) as Int)- cast(SUBSTRING(DBO.getShamsiDate(@StartDate2),9,2) as Int)+1
			  SELECT @MountCount=@Mount-cast(SUBSTRING(DBO.getShamsiDate(@StartDate2),6,2) as Int)
			   			 
			--IF DATEPART(DAY,@EndDate2) > DATEPART(DAY,@StartDate2)	
			--BEGIN			
			--  SELECT @Mount=DATEPART(M,@EndDate2)
			--  SELECT @DayCount=DATEPART(DAY,@EndDate2)-DATEPART(DAY,@StartDate2)
			--  SELECT @MountCount=@Mount-DATEPART(M,@StartDate2)
			  
			  IF @Mount<=6
			   SET @Divided=31
			  ELSE IF @Mount=12
			   SET @Divided=29
			  ELSE IF @Mount>6
			   SET @Divided=30		   		   
			   
			  UPDATE @TemporaryTemp SET DiscountPrice=ROUND(((DiscountPrice*@MountCount)+(@DayCount*(DiscountPrice/@Divided))),0),
			    Price=ROUND(((Price*@MountCount)+(@DayCount*(Price/@Divided))),0) 
				  WHERE FieldName='Cost2'
			END
					  
		   ELSE IF SUBSTRING(DBO.getShamsiDate(@EndDate2),9,2)< SUBSTRING(DBO.getShamsiDate(@StartDate2),9,2)
			 BEGIN				
			  SELECT @Mount=cast(SUBSTRING(DBO.getShamsiDate(@EndDate2),6,2)as Int)-1			  		  
			  SELECT @DayCount=SUBSTRING(DBO.getShamsiDate(@EndDate2),9,2)			  
			  SELECT @MountCount=@Mount-cast(SUBSTRING(DBO.getShamsiDate(@StartDate2),6,2) as Int)
			  

			--ELSE IF DATEPART(DAY,@EndDate2) < DATEPART(DAY,@StartDate2)
			-- BEGIN				
			--  SELECT @Mount=DATEPART(M,@EndDate2)-1			  		  
			--  SELECT @DayCount=DATEPART(DAY,@EndDate2)			  
			--  SELECT @MountCount=@Mount-DATEPART(M,@StartDate2)
			  
			  IF @Mount<=6
			   SET @Divided=31
			  ELSE IF @Mount=12
			   SET @Divided=29
			  ELSE IF @Mount>6
			   SET @Divided=30		   		   

			  IF (@Mount-1) = 0
			   SET @Divided2=31
			  ELSE IF (@Mount-1)<=6
			   SET @Divided2=29
			  ELSE IF (@Mount-1)>6
			   SET @Divided2=30
			   	
			  SELECT @DayCount2=@Divided2-cast(SUBSTRING(DBO.getShamsiDate(@StartDate2),9,2) as Int)

			  --SELECT @DayCount2=@Divided2-DATEPART(DAY,@StartDate2)

			   UPDATE @TemporaryTemp SET
				DiscountPrice=ROUND(((DiscountPrice*@MountCount)+(@DayCount*(DiscountPrice/@Divided))+(@DayCount2*(DiscountPrice/@Divided2))),0),
				 Price=ROUND(((Price*@MountCount)+(@DayCount*(Price/@Divided))+(@DayCount2*(Price/@Divided2))),0)
				  WHERE FieldName='Cost2'		      		      		      
			END	
	    END	    
	--========================================================================================
	 -- يكي كردن قیمتها بر اساس نوع فضا
	    INSERT INTO @SpaceTypeTBL
	      SELECT DISTINCT SpaceType FROM @TemporaryTemp 
	    
	    WHILE (SELECT COUNT(*) FROM @SpaceTypeTBL)>0
	    BEGIN
	       SELECT TOP 1 @SpaceType=SpaceType from @SpaceTypeTBL
	       
	       IF EXISTS (select * from @TemporaryTemp where SpaceType=@SpaceType AND OI=N'اداری')
	        BEGIN
	          SELECT @TotalDiscountCost=SUM(DiscountPrice) FROM @TemporaryTemp WHERE SpaceType=@SpaceType AND OI=N'اداری'
	          SELECT @TotalCost=SUM(Price) FROM @TemporaryTemp WHERE SpaceType=@SpaceType AND OI=N'اداری'
	       
		      UPDATE @TemporaryTemp SET Price=@TotalCost,
			     DiscountPrice=@TotalDiscountCost WHERE SpaceType=@SpaceType AND OI=N'اداری'
		    END 
	       DELETE FROM @SpaceTypeTBL WHERE SpaceType=@SpaceType
	     END 
	     
	    INSERT INTO @SpaceTypeTBL
	      SELECT DISTINCT SpaceType FROM @TemporaryTemp 
	    
	    WHILE (SELECT COUNT(*) FROM @SpaceTypeTBL)>0
	    BEGIN
	       SELECT TOP 1 @SpaceType=SpaceType from @SpaceTypeTBL
	       
	       IF EXISTS (select * from @TemporaryTemp where SpaceType=@SpaceType AND OI=N'تاسیسات')
	        BEGIN	       
			   SELECT @TotalDiscountCost=SUM(DiscountPrice) FROM @TemporaryTemp WHERE SpaceType=@SpaceType AND OI=N'تاسیسات'
			   SELECT @TotalCost=SUM(Price) FROM @TemporaryTemp WHERE SpaceType=@SpaceType AND OI=N'تاسیسات'
		       
			   UPDATE @TemporaryTemp SET Price=@TotalCost,
				 DiscountPrice=@TotalDiscountCost WHERE SpaceType=@SpaceType AND OI=N'تاسیسات'
			 END
	       DELETE FROM @SpaceTypeTBL WHERE SpaceType=@SpaceType
	     END 	     
	 --============================================================================================================
     -- يكي كردن سطرها بر اساس نوع فضا	 
	 DECLARE @Tbl table(ReportDATE nvarchar(20),Functor nvarchar(1),Rtrn nvarchar(2),CompanyID int,CompanyName nvarchar(max),OLDFinancialCode nvarchar(4)
               ,NEWFinancialCode nvarchar(10),BuildingName nvarchar(max),BuildingCode nvarchar(3),S1 nvarchar(20),S2 nvarchar(20)
                             ,SpaceType nvarchar(50),Price int,DiscountPrice int,Discount int)
     
     INSERT INTO @Tbl
	  SELECT DISTINCT dbo.getshamsidate(getdate()),'1','',CompanyID,CompanyName ,FinancialCode ,NewFinancialCode ,BuildingName ,BuildingCode 
				   ,ContractType ,OI ,SpaceType ,Price ,DiscountPrice,(Price-DiscountPrice)  FROM @TemporaryTemp   
	 
	 while (select COUNT(*) from @Tbl)>0
	 begin 
	   
	   select top 1 @SpaceType=SpaceType,@BuildingCode=BuildingCode,@Price=Price,
	        @DiscountPrice=DiscountPrice,@Discount=Discount,@OI=S2 from @Tbl
	      
	        
	   if exists (select * from @MainTable where CompanyID=@CompanyID and BuildingCode=@BuildingCode and
	              SpaceType=@SpaceType and S2=@OI)
	              
	     update @MainTable set Price=cast(Price as int)+@Price,DiscountPrice=cast(DiscountPrice as int)+@DiscountPrice
	      ,Discount=cast(Discount as int)+@Discount
	       where CompanyID=@CompanyID and BuildingCode=@BuildingCode and SpaceType=@SpaceType and S2=@OI         
	      
	  else                           
	   INSERT INTO @MainTable
	      SELECT ReportDATE ,Functor ,Rtrn ,CompanyID ,CompanyName ,OLDFinancialCode 
             ,NEWFinancialCode ,BuildingName ,BuildingCode ,S1 ,S2 
                ,SpaceType ,Price ,DiscountPrice ,Discount
                   FROM @Tbl WHERE CompanyID=@CompanyID and BuildingCode=@BuildingCode and
	                   SpaceType=@SpaceType and S2=@OI
	      
	  DELETE @Tbl where SpaceType=@SpaceType and S2=@OI	
	 end
	 
	 DELETE @DCTemp where DocumentCode=@DCContracts					
     
   --select * from @MainTable
   --select * from @DelayTemp
  --=========================================================================================================================================
  --محاسبه ي مبلغ ديركرد
  DECLARE @SpaceCodeD NVARCHAR(10)
  DECLARE @SpaceTypeD NVARCHAR(10)  
  DECLARE @S2 NVARCHAR(20)        -- اداری یا تاسیسات
  DECLARE @MonthlyPriceD float    --قیمت ماهانه بدون تخفیف
  DECLARE @ContractEndDate DATE   -- تاريخ پايان قرارداد
  DECLARE @ReturnDate DATE        -- تاريخ عودت فضا

  --------------------
  -- تاريخ پايان قرارداد
  IF @EndDate2<>'' and @EndDate2<>'1900-01-01' and @EndDate2<>'Jan  1 1900 12:00AM' and @EndDate2 IS NOT NULL
   SET @ContractEndDate=@EndDate2
  ELSE
   SET @ContractEndDate=@EndDate  
  
  --اگر تاریخ پایان قرارداد قبل از شروع بازه ی گزارشگیری بود از تاریخ شروع گزارشگیری مبلغ دیرکرد را محاسبه میکنیم
  IF @ContractEndDate < @EarlierDate
     SET @ContractEndDate=@EarlierDate
 
  -------------------- 
  WHILE (SELECT COUNT(*) FROM @DelayTemp)>0
  BEGIN
    SELECT TOP 1 @SpaceCodeD=SpaceCode,
				 @SpaceTypeD=SpaceType,
				 @MonthlyPriceD=Price,
				 @S2=S2 FROM @DelayTemp    
  
    IF NOT EXISTS (SELECT * FROM WSI_SUCF_ChangeSpace_Compile WHERE 
     SUCF29H01_CompanyUserCode=@CompanyID AND SUCF29H01_BuildingSelection=@BuildingCode 
      AND SUCF29H01_IntendedReturnSpace_SubFields_XML LIKE '%"'+@SpaceCodeD+'"%'
        AND SUCF29H01_EvacuationPermission=1) 
      --اگر عودت فضايي براي اين فضا نداشتيم تاريخ عودت را تاریخ پایان گزارش ميگيريم
      SET @ReturnDate=@EndDateFltr
     
    ELSE IF EXISTS (SELECT * FROM WSI_SUCF_ChangeSpace_Compile WHERE 
     SUCF29H01_CompanyUserCode=@CompanyID AND SUCF29H01_BuildingSelection=@BuildingCode 
      AND SUCF29H01_IntendedReturnSpace_SubFields_XML LIKE '%"'+@SpaceCodeD+'"%'
        AND SUCF29H01_EvacuationPermission=1) 
      --اگر عودت فضايي براي اين فضا داشتيم تاريخ عودت را تاريخ عودت روي فرم عودت را ميگيريم
      SELECT @ReturnDate=SUCF29H01_ReturnDate FROM WSI_SUCF_ChangeSpace_Compile WHERE 
       SUCF29H01_CompanyUserCode=@CompanyID AND SUCF29H01_BuildingSelection=@BuildingCode 
        AND SUCF29H01_IntendedReturnSpace_SubFields_XML LIKE '%"'+@SpaceCodeD+'"%' 
          AND SUCF29H01_EvacuationPermission=1
       
       IF @ReturnDate>@EndDateFilter
         SET @ReturnDate=@EndDateFltr
         
          --select dbo.getShamsiDate(@ReturnDate)
          
 	   IF SUBSTRING(DBO.getShamsiDate(@ReturnDate),9,2)>= SUBSTRING(DBO.getShamsiDate(@ContractEndDate),9,2)
 	      and @ReturnDate > @EarlierDate
			BEGIN		
			  IF @ContractEndDate=@EarlierDate
			    SELECT @DayCount=cast(SUBSTRING(DBO.getShamsiDate(@ReturnDate),9,2) as Int)- cast(SUBSTRING(DBO.getShamsiDate(@ContractEndDate),9,2) as Int)+1
			  
			  ELSE 
			    SELECT @DayCount=cast(SUBSTRING(DBO.getShamsiDate(@ReturnDate),9,2) as Int)- cast(SUBSTRING(DBO.getShamsiDate(@ContractEndDate),9,2) as Int)
			  
			  SELECT @Mount=SUBSTRING(DBO.getShamsiDate(@ReturnDate),6,2)
			  --SELECT @DayCount=cast(SUBSTRING(DBO.getShamsiDate(@ReturnDate),9,2) as Int)- cast(SUBSTRING(DBO.getShamsiDate(@ContractEndDate),9,2) as Int)
			  SELECT @MountCount=@Mount-cast(SUBSTRING(DBO.getShamsiDate(@ContractEndDate),6,2) as Int)
			  
			  IF @Mount<=6
			   SET @Divided=31
			  ELSE IF @Mount=12
			   SET @Divided=29
			  ELSE IF @Mount>6
			   SET @Divided=30	
			  
			  --IF @ContractEndDate=@EarlierDate 			      
			  -- UPDATE @MainTable SET DiscountPrice=ROUND(((@MonthlyPriceD*@MountCount)+((@DayCount*(@MonthlyPriceD/@Divided)))),0),
			  --   Price=ROUND(((@MonthlyPriceD*@MountCount)+((@DayCount*(@MonthlyPriceD/@Divided)))),0) 
				 -- WHERE SpaceType=@SpaceTypeD and S2=@S2
				  
			  --ELSE IF @ContractEndDate=@EarlierDate 			      
			   UPDATE @MainTable SET DiscountPrice=ROUND((cast(DiscountPrice as float)+(@MonthlyPriceD*@MountCount)+(@DayCount*(@MonthlyPriceD/@Divided))),0),
			     Price=ROUND((cast(Price as float)+(@MonthlyPriceD*@MountCount)+(@DayCount*(@MonthlyPriceD/@Divided))),0) 
				  WHERE SpaceType=@SpaceTypeD and S2=@S2 and CompanyID=@CompanyID and BuildingCode=@BuildingCode			  
			END
					  
		   ELSE IF SUBSTRING(DBO.getShamsiDate(@ReturnDate),9,2)< SUBSTRING(DBO.getShamsiDate(@ContractEndDate),9,2)
		    and @ReturnDate > @EarlierDate
			 BEGIN				
			  SELECT @Mount=cast(SUBSTRING(DBO.getShamsiDate(@ReturnDate),6,2)as Int)-1			  		  
			  SELECT @DayCount=SUBSTRING(DBO.getShamsiDate(@ReturnDate),9,2)			  
			  SELECT @MountCount=@Mount-cast(SUBSTRING(DBO.getShamsiDate(@ContractEndDate),6,2) as Int)
			  

			  IF @Mount<=6
			   SET @Divided=31
			  ELSE IF @Mount=12
			   SET @Divided=29
			  ELSE IF @Mount>6
			   SET @Divided=30		   		   

			  IF (@Mount-1) = 0
			   SET @Divided2=31
			  ELSE IF (@Mount-1)<=6
			   SET @Divided2=29
			  ELSE IF (@Mount-1)>6
			   SET @Divided2=30
			   	
			  SELECT @DayCount2=@Divided2-cast(SUBSTRING(DBO.getShamsiDate(@ContractEndDate),9,2) as Int)

			  --SELECT @DayCount2=@Divided2-DATEPART(DAY,@StartDate2)

			   UPDATE @MainTable SET
				DiscountPrice=
				 ROUND((cast(DiscountPrice as float)+(@MonthlyPriceD*@MountCount)+(@DayCount*(@MonthlyPriceD/@Divided))+(@DayCount2*(@MonthlyPriceD/@Divided2))),0),
				 Price=
				 ROUND((cast(Price as float)+(@MonthlyPriceD*@MountCount)+(@DayCount*(@MonthlyPriceD/@Divided))+(@DayCount2*(@MonthlyPriceD/@Divided2))),0)
				  WHERE SpaceType=@SpaceTypeD and S2=@S2 and CompanyID=@CompanyID and BuildingCode=@BuildingCode
			END	      
			
      DELETE FROM @DelayTemp WHERE SpaceCode=@SpaceCodeD AND Price=@MonthlyPriceD and @S2=S2
      
     END
    END
  --=========================================================================================================================================
  insert into WSI_SUCF50Table
    select * from @MainTable     
  --=========================================================================================================================================
  
  --کد عددی ساختمان
  UPDATE WSI_SUCF50Table SET BuildingCode=
	(select SUCF03H01_AccountingCode from WSI_SUCF_TownBuildings where SUCF03H01_BuildingsCode=BuildingCode)
	  
    SET @SqlCommand =' SELECT ReportDATE ,Functor ,Rtrn ,CompanyName ,OLDFinancialCode ,NEWFinancialCode ,BuildingName ,BuildingCode ,S1 ,S2,SpaceType ,Price ,DiscountPrice ,Discount FROM WSI_SUCF50Table ORDER BY '+@SortOF+' '+@SortType
                            
                             
    --INSERT INTO WSI_SUCF50Table
     SELECT N' تاریخ ',N' انجام خدمات ',N' برگشت خدمات ',N' گیرنده خدمات ',N' کد حساب قدیم گیرنده خدمات ',N' کد حساب جدید گیرنده خدمات '
     ,N' ارائه دهنده خدمات ',N' کد واحد ارائه دهنده خدمات ',N' موضوع ',N' موضوع ',N' نوع فضا ',N' مبلغ ',N' مبلغ با تخفیف ',N' میزان تخفیف '
   
    EXEC (@SqlCommand)
    
    DELETE WSI_SUCF50Table
   
   END
   
  END
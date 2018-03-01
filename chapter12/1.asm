                ;设置堆栈段和栈指针 
                mov eax,cs      
                mov ss,eax
                mov sp,0x7c00
             
                ;计算GDT所在的逻辑段地址
                mov eax,[cs:pgdt+0x7c00+0x02]      ;GDT的32位线性基地址 
                xor edx,edx
                mov ebx,16
                div ebx                            ;分解成16位逻辑地址 
       
                mov ds,eax                         ;令DS指向该段以进行操作
                mov ebx,edx                        ;段内起始偏移地址 
       
                ;创建0#描述符，它是空描述符，这是处理器的要求
                mov dword [ebx+0x00],0x00000000
                mov dword [ebx+0x04],0x00000000  
       
                ;1#描述符，数据段，1MB~4GB的线性地址空间
                mov dword [ebx+0x08],0x0000ffff    
                mov dword [ebx+0x0c],0x00cf9210    
       
                ;创建保护模式下初始代码段描述符
                mov dword [ebx+0x10],0x7c0001ff    ;基地址为0x00007c00，512字节 
                mov dword [ebx+0x14],0x00409800    ;粒度为1个字节，代码段描述符 
                
                ;显存段
                mov dword [ebx + 0x18], 0x80008000
                mov dword [ebx + 0x1c], 0x0040920b
       
                ;初始化描述符表寄存器GDTR
                mov word [cs: pgdt+0x7c00], 31        
        
                lgdt [cs: pgdt+0x7c00]
             
                in al,0x92                         ;南桥芯片内的端口 
                or al,0000_0010B
                out 0x92,al                        ;打开A20
       
                cli                                ;中断机制尚未工作
       
                mov eax,cr0
                or eax,1
                mov cr0,eax                        ;设置PE位
             
                ;以下进入保护模式... ...
                jmp dword 0x0010:check             ;16位的描述符选择子：32位偏移
                                                    
                [bits 32]                          
         check:                                            
                mov eax,0x0008                     
                mov ds, eax
                mov eax, 0x18
                mov es, eax
       
                ;每次检测4B，所以总共需要检测(4GB - 1MB) / 4 次
                mov eax, 1073479680
                mov ecx, eax
       
                ;每次检测的内存地址
                xor ebx, ebx
       
           @1:  mov dword [ebx], 0x55AA55AA
                mov eax, [ebx]
                cmp eax, 0x55AA55AA
                jne fail
       
                mov dword [ebx], 0xAA55AA55
                mov eax, [ebx]
                cmp eax, 0xAA55AA55
                jne fail
       
                ;当前双字检测成功
                add ebx, 4
                ;累加检测数量
                mov eax, ebx
                call show_checked
       
                loop @1
       
                ;检测成功
                jmp done
       
          fail: ;检测失败，显示错误信息
                mov byte [es:160], 'f'
                mov byte [es:162], 'a'
                mov byte [es:164], 'i'
                mov byte [es:166], 'l'
       
          done: hlt   

              ; 子程序: 显示已经检查的字节数
show_checked:   push edx
                push esi
                push ecx
                
                xor edx, edx
                xor ecx, ecx
                mov esi, 10

            @2: div esi
                ; 保存余数用于显示
                push edx
                inc ecx
                xor edx, edx
                
                cmp eax, 0
                je @3
                
                jmp @2
                
            @3: xor esi, esi
            @4: pop edx
                add edx, 48
                mov [es:esi], dl
                add esi, 2
                loop @4
                
                pop ecx
                pop esi
                pop edx
                
                ret
                
;-------------------------------------------------------------------------------
     pgdt             dw 0
                      dd 0x00007e00      ;GDT的物理地址
;-------------------------------------------------------------------------------                             
     times 510-($-$$) db 0
                      db 0x55,0xaa